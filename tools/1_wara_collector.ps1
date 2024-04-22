<#
The goal of this tool is to execute ARGs from APRL and export the results to a JSON file.

APRL Repo will be downloaded in the script's folder
#>

Param(
  [switch]$Debugging,
  [switch]$Help,
  $RunbookFile,
  $SubscriptionsFile,
  $SubscriptionIds,
  $ResourceGroups,
  $TenantID)

if ($Debugging.IsPresent) { $DebugPreference = 'Continue' } else { $DebugPreference = "silentlycontinue" }

Clear-Host

$Global:CShell = try { Get-CloudDrive }catch { "" }
$Global:SubscriptionIds = $SubscriptionIds

$Global:Runtime = Measure-Command -Expression {

  function CheckParameters {
    if ([string]::IsNullOrEmpty($SubscriptionIds) -and [string]::IsNullOrEmpty($SubscriptionsFile)) {
      Write-Host ""
      Write-Host "Suscription ID or Subscription File is required"
      Write-Host ""
      Exit
    }
  }

  function Help {
    Write-Host ""
    Write-Host "Parameters"
    Write-Host ""
    Write-Host " -TenantID <ID>        :  Optional; tenant to be used. "
    Write-Host " -SubscriptionIds <IDs>:  Optional (or SubscriptionsFile); Specifies Subscription(s) to be included in the analysis: Subscription1,Subscription2. "
    Write-Host " -SubscriptionsFile    :  Optional (or SubscriptionIds); specifies the file with the subscription list to be analysed (one subscription per line). "
    Write-Host " -RunbookFile          :  Optional; specifies the file with the runbook (selectors & checks) to be used. "
    Write-Host " -ResourceGroups       :  Optional; specifies Resource Group(s) to be included in the analysis: ResourceGroup1,ResourceGroup2. "
    Write-Host " -Debug                :  Writes Debugging information of the script during the execution. "
    Write-Host ""
    Write-Host "Examples: "
    Write-Host "  Run against all the subscriptions in the Tenant"
    Write-Host "  .\1_wara_collector.ps1 -TenantID XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"
    Write-Host ""
    Write-Host "  Run against specific Subscriptions in the Tenant"
    Write-Host "  .\1_wara_collector.ps1 -TenantID XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX -SubscriptionIds YYYYYYYY-YYYY-YYYY-YYYY-YYYYYYYYYYYY,AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA"
    Write-Host ""
    Write-Host "  Run against the subscriptions in a file the Tenant"
    Write-Host '  .\1_wara_collector.ps1 -TenantID XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX -SubscriptionsFile "C:\Temp\Subscriptions.txt"'
    Write-Host ""
    Write-Host ""
  }

  function Variables {
    $Global:SubIds = ''
    $Global:RunbookChecks = @{}
    $Global:RunbookQueryOverrides = @()
    $Global:RunbookSelectors = @{}
    $Global:AllResourceTypes = @()
    $Global:AllResourceTypesOrdered = @()
    $Global:AllAdvisories = @()
    $Global:AllRetirements = @()
    $Global:AllServiceHealth = @()
    $Global:results = @()
  }

  function Requirements {
    # Install required modules
    try {
      Write-Host "Validating " -NoNewline
      Write-Host "Az.ResourceGraph" -ForegroundColor Cyan -NoNewline
      Write-Host " Module.."
      $AzModules = Get-Module -Name Az.ResourceGraph -ListAvailable -ErrorAction silentlycontinue
      if ($null -eq $AzModules) {
        Write-Host "Installing Az Modules" -ForegroundColor Yellow
        Install-Module -Name Az.ResourceGraph -SkipPublisherCheck -InformationAction SilentlyContinue
      }
      Write-Host "Validating " -NoNewline
      Write-Host "Git" -ForegroundColor Cyan -NoNewline
      Write-Host " Installation.."
      $GitVersion = git --version
      if ($null -eq $GitVersion) {
        Write-Host "Missing Git" -ForegroundColor Red
        Exit
      }
    }
    catch {
      # Report Error
      $errorMessage = $_.Exception.Message
      Write-Host "Error executing function Requirements: $errorMessage" -ForegroundColor Red
    }
  }

  function LocalFiles {
    Write-Debug "Setting local path"
    try {
      # Clone the GitHub repository to a temporary folder
      #$repoUrl = "https://github.com/azure/Azure-Proactive-Resiliency-Library"
      $repoUrl = "https://github.com/Azure/Azure-Proactive-Resiliency-Library-v2"

      # Define script path as the default path to save files
      $workingFolderPath = $PSScriptRoot
      Set-Location -path $workingFolderPath;
      if (!$Global:CShell) {
        $Global:clonePath = "$workingFolderPath\Azure-Proactive-Resiliency-Library"
      }
      else {
        $Global:clonePath = "$workingFolderPath/Azure-Proactive-Resiliency-Library"
      }
      Write-Debug "Checking default folder"
      if ((Get-ChildItem -Path $Global:clonePath -Force -ErrorAction SilentlyContinue | Measure-Object).Count -gt 0) {
        Write-Debug "APRL Folder does exist. Reseting it..."
        Get-Item -Path $Global:clonePath | Remove-Item -Recurse -Force
        git clone $repoUrl $clonePath --quiet
      }
      else {
        git clone $repoUrl $clonePath --quiet
      }
      Write-Debug "Checking the version of the script"
      if (!$Global:CShell) {
        $RepoVersion = Get-Content -Path "$clonePath/tools/Version.json" -ErrorAction SilentlyContinue | ConvertFrom-Json
      }
      else {
        $RepoVersion = Get-Content -Path "$clonePath\tools\Version.json" -ErrorAction SilentlyContinue | ConvertFrom-Json
      }
      if ($Version -ne $RepoVersion.Collector) {
        Write-Host "This version of the script is outdated. " -BackgroundColor DarkRed
        Write-Host "Please use a more recent version of the script." -BackgroundColor DarkRed
      }
      else {
        Write-Host "This version of the script is current version. " -BackgroundColor DarkGreen
      }
    }
    catch {
      # Report Error
      $errorMessage = $_.Exception.Message
      Write-Host "Error executing function LocalFiles: $errorMessage" -ForegroundColor Red
    }
  }

  function ConnectToAzure {
    # Connect To Azure Tenant
    Write-Host "Authenticating to Azure"
    if (!$Global:CShell) {
      az account clear | Out-Null
      Clear-AzContext -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue -InformationAction SilentlyContinue
      if ([string]::IsNullOrEmpty($TenantID)) {
        write-host "Tenant ID not specified."
        write-host ""
        Connect-AzAccount -WarningAction SilentlyContinue
        $Tenants = Get-AzTenant
        if ($Tenants.count -gt 1) {
          Write-Host "Select the Azure Tenant to connect : "
          $Selection = 1
          foreach ($Tenant in $Tenants) {
            $TenantName = $Tenant.Name
            write-host "$Selection)  $TenantName"
            $Selection ++
          }
          write-host ""
          [int]$SelectedTenant = read-host "Select Tenant"
          $defaultTenant = --$SelectedTenant
          $TenantID = $Tenants[$defaultTenant]
          Connect-AzAccount -Tenant $TenantID -WarningAction SilentlyContinue
          #az login --tenant $TenantID --only-show-errors
        }
      }
      else {
        #az login --tenant $TenantID --only-show-errors
        Connect-AzAccount -Tenant $TenantID -WarningAction SilentlyContinue
      }
      #Set the default variable with the list of subscriptions in case no Subscription File was informed
      $Global:SubIds = Get-AzSubscription -TenantId $TenantID -WarningAction SilentlyContinue
    }
    else {
      Connect-AzAccount -Identity
      $Global:SubIds = Get-AzSubscription -WarningAction SilentlyContinue
    }

    # Getting Outages
    Write-Debug "Exporting Outages"
    $Date = (Get-Date).AddMonths(-24)
    $DateOutages = (Get-Date).AddMonths(-3)
    $DateCore = (Get-Date).AddMonths(-3)
    $Date = $Date.ToString("MM/dd/yyyy")
    $Outages = @()
    $SupTickets = @()
    foreach ($sub in $SubscriptionIds) {
      Select-AzSubscription -Subscription $sub -WarningAction SilentlyContinue -InformationAction SilentlyContinue | Out-Null

      $Token = Get-AzAccessToken

      $header = @{
        'Authorization' = 'Bearer ' + $Token.Token
      }

      try {
        $url = ('https://management.azure.com/subscriptions/' + $Sub + '/providers/Microsoft.ResourceHealth/events?api-version=2022-10-01&queryStartTime=' + $Date)
        $Outages += Invoke-RestMethod -Uri $url -Headers $header -Method GET
      }
      catch { $null }

      try {
        $supurl = ('https://management.azure.com/subscriptions/' + $sub + '/providers/Microsoft.Support/supportTickets?api-version=2020-04-01')
        $SupTickets += Invoke-RestMethod -Uri $supurl -Headers $header -Method GET
      }
      catch { $null }
    }

    $Global:Outageslist = $Outages.value | Where-Object { $_.properties.impactStartTime -gt $DateOutages } | Sort-Object @{Expression = "properties.eventlevel"; Descending = $false }, @{Expression = "properties.status"; Descending = $false } | Select-Object -Property name, properties -First 15
    $Global:RetiredOutages = $Outages.value | Sort-Object @{Expression = "properties.eventlevel"; Descending = $false }, @{Expression = "properties.status"; Descending = $false } | Select-Object -Property name, properties
    $Global:SupportTickets = $SupTickets.value | Where-Object { $_.properties.severity -ne 'Minimal' -and $_.properties.createdDate -gt $DateCore } | Select-Object -Property name, properties
  }

  function Runbook {
    # Checks if a runbook file was provided and, if so, loads selectors and checks hashtables
    if (![string]::IsNullOrEmpty($RunbookFile)) {

      Write-Host "A runbook has been configured. Only checks configured in the runbook will be run."

      # Check that the runbook file actually exists
      if (Test-Path $RunbookFile -PathType Leaf) {

        # Try to load runbook JSON
        $RunbookJson = Get-Content -Raw $RunbookFile | ConvertFrom-Json

        # Try to load selectors
        $RunbookJson.selectors.PSObject.Properties | ForEach-Object {
          $Global:RunbookSelectors[$_.Name.ToLower()] = $_.Value
        }

        # Try to load checks
        $RunbookJson.checks.PSObject.Properties | ForEach-Object {
          $Global:RunbookChecks[$_.Name.ToLower()] = $_.Value
        }

        # Try to load query overrides
        $RunbookJson.query_overrides | ForEach-Object {
          $Global:RunbookQueryOverrides += [string]$_
        }
      }

      Write-Host "The provided runbook includes $($Global:RunbookChecks.Count.ToString()) check(s). Only checks configured in the runbook will be run."
    }
  }

  function Subscriptions {
    # Checks if the Subscription file  and TenantID were informed
    if (![string]::IsNullOrEmpty($SubscriptionsFile)) {
      #$filePath = Read-Host "Please provide the path to a text file containing subscription IDs (one SubId per line)"

      # Check if the file exists
      if (Test-Path $SubscriptionsFile -PathType Leaf) {
        # Read the content of the file and split it into an array of subscription IDs
        $Global:SubIds = Get-Content $SubscriptionsFile -ErrorAction Stop | ForEach-Object { $_ -split ',' }

        # Display the subscription IDs
        Write-Host "---------------------------------------------------------------------"
        Write-Host "Executing Analysis from Subscription File: " -NoNewline
        Write-Host $SubscriptionsFile -ForegroundColor Blue
        Write-Host "---------------------------------------------------------------------"
        Write-Host "The following Subscription IDs were found: "
        Write-Host $SubIds
      }
      else {
        Write-Host "File not found: $SubscriptionsFile"
      }
    }
  }

  function PSExtraction {
    $SideScripts = Get-ChildItem -Path "$PSScriptRoot\Azure-Proactive-Resiliency-Library\docs\content\services" -Filter "*.ps1" -Recurse
    if (![string]::IsNullOrEmpty($SubscriptionIds) -and [string]::IsNullOrEmpty($SubscriptionsFile)) {
      $SubIds = $SubIds | Where-Object { $_.Id -in $SubscriptionIds }
    }

    Write-Debug 'Starting Extra Powershell Scripts loop'
    foreach ($Subscription in $SubIds) {
      $SubID = $Subscription.id
      $SubName = $Subscription.name

      Write-Host 'Running APRL PS Scripts for the Subscription: ' -NoNewline
      Write-Host $SubName -ForegroundColor Green

      Start-Job -Name ('PSExtraction_' + $SubID) -ScriptBlock {
        Set-AzContext -Subscription $($args[0]) -WarningAction SilentlyContinue
        #az account set --subscription $($args[0]) --only-show-errors
        $SideScripts = $($args[1])
        $ViableScripts = @()
        $job = @()

        foreach ($Script in $SideScripts) {
          $ScriptName = $Script.Name.Substring(0, $Script.Name.length - ".ps1".length)
          $ScriptFull = New-Object System.IO.StreamReader($Script.FullName)
          $ScriptReady = $ScriptFull.ReadToEnd()
          $ScriptFull.Dispose()

          if ($ScriptReady -like '# Azure PowerShell script*') {
            $ViableScripts += $Script
            New-Variable -Name ('ScriptRun_' + $ScriptName) #-ErrorAction SilentlyContinue
            New-Variable -Name ('ScriptJob_' + $ScriptName) #-ErrorAction SilentlyContinue
            Set-Variable -Name ('ScriptRun_' + $ScriptName) -Value ([PowerShell]::Create()).AddScript($ScriptReady).AddArgument($($args[2])).AddArgument($($args[0]))
            Set-Variable -Name ('ScriptJob_' + $ScriptName) -Value ((get-variable -name ('ScriptRun_' + $ScriptName)).Value).BeginInvoke()
            $job += (get-variable -name ('ScriptJob_' + $ScriptName)).Value
          }
        }

        while ($Job.Runspace.IsCompleted -contains $false) { Start-Sleep -Milliseconds 100 }

        foreach ($Script in $ViableScripts) {
          $ScriptName = $Script.Name.Substring(0, $Script.Name.length - ".ps1".length)
          New-Variable -Name ('ScriptValue_' + $ScriptName) #-ErrorAction SilentlyContinue
          Set-Variable -Name ('ScriptValue_' + $ScriptName) -Value (((get-variable -name ('ScriptRun_' + $ScriptName)).Value).EndInvoke((get-variable -name ('ScriptJob_' + $ScriptName)).Value))
        }

        $Hashtable = New-Object System.Collections.Hashtable

        foreach ($Script in $ViableScripts) {
          $ScriptName = $Script.Name.Substring(0, $Script.Name.length - ".ps1".length)
          $Hashtable["$ScriptName"] = (get-variable -name ('ScriptValue_' + $ScriptName)).Value
        }

        $Hashtable
      } -ArgumentList $SubID, $SideScripts, $ResourceGroups

    }

    Write-Debug 'Starting to Process Jobs'
    $JobNames = @()
    Foreach ($Job in (Get-Job | Where-Object { $_.name -like 'PSExtraction_*' })) {
      $JobNames += $Job.Name
    }

    while (get-job -Name $JobNames | Where-Object { $_.State -eq 'Running' }) {
      $jb = get-job -Name $JobNames
      Write-Debug ('Jobs Running: ' + [string]($jb | Where-Object { $_.State -eq 'Running' }).count)
      Start-Sleep -Seconds 2
    }

    foreach ($Job in $JobNames) {
      $TempJob = Receive-Job -Name $Job -WarningAction SilentlyContinue
      Write-Debug ('Job ' + $Job + ' Returned: ' + ($TempJob.values | Where-Object { $_ -ne $null }).Count)
      foreach ($key in $TempJob.Keys) {
        if ($TempJob.$key) {
          foreach ($data in $TempJob.$key) {
            $result = [PSCustomObject]@{
              recommendationId = [string]$data.recommendationId
              name             = [string]$data.name
              id               = [string]$data.id
              tags             = [string]$data.tags
              param1           = [string]$data.param1
              param2           = [string]$data.param2
              param3           = [string]$data.param3
              param4           = [string]$data.param4
              param5           = [string]$data.param5
              checkName        = ''
            }
            if (![string]::IsNullOrEmpty($result.recommendationId)) {
              $Global:results += $result
            }
          }
        }
      }
    }

    foreach ($Job in $JobNames) {
      Remove-Job $Job -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    }
  }

  function ResourceExtraction {

    function QueryCollector {
      param($Subid, $type, $query, $checkId, $checkName, $validationAction)
      try {
        $ResourceType = $Global:AllResourceTypes | Where-Object { $_.type -eq $type -and $_.subscriptionId -eq $Subid }
        if ($resourceType.count_ -lt 1000) {
          # Execute the query and collect the results
          $queryResults = Search-AzGraph -Query $query -First 1000 -Subscription $Subid -ErrorAction SilentlyContinue

          # Filter out the resources based on Subscription
          # $queryResults = $queryResults | Where-Object {$_.id.split('/')[2] -eq $Subid}

          foreach ($row in $queryResults) {

            $result = [PSCustomObject]@{
              validationAction = [string]$validationAction
              recommendationId = [string]$checkId
              name             = [string]$row.name
              id               = [string]$row.id
              tags             = [string]$row.tags
              param1           = [string]$row.param1
              param2           = [string]$row.param2
              param3           = [string]$row.param3
              param4           = [string]$row.param4
              param5           = [string]$row.param5
              checkName        = [string]$checkName
              selector         = [string]$selector
            }
            $Global:results += $result
          }
        }
        else {
          $Loop = $resourceType.count_ / 1000
          $Loop = [math]::ceiling($Loop)
          $Looper = 0
          $Limit = 1

          while ($Looper -lt $Loop) {
            $queryResults = Search-AzGraph -Query ($query + '| order by id') -Subscription $Subid -Skip $Limit -first 1000 -ErrorAction SilentlyContinue
            foreach ($row in $queryResults) {
              $result = [PSCustomObject]@{
                validationAction = [string]$validationAction
                recommendationId = [string]$checkId
                name             = [string]$row.name
                id               = [string]$row.id
                tags             = [string]$row.tags
                param1           = [string]$row.param1
                param2           = [string]$row.param2
                param3           = [string]$row.param3
                param4           = [string]$row.param4
                param5           = [string]$row.param5
                checkName        = [string]$checkName
                selector         = [string]$selector
              }
              $Global:results += $result
            }
            $Looper ++
            $Limit = $Limit + 1000
          }
        }
      }
      catch {
        # Report Error
        $errorMessage = $_.Exception.Message
        Write-Host "Error processing query results: $errorMessage" -ForegroundColor Red
      }
    }


    if (![string]::IsNullOrEmpty($SubscriptionIds) -and [string]::IsNullOrEmpty($SubscriptionsFile)) {
      $SubIds = $SubIds | Where-Object { $_.Id -in $SubscriptionIds }
    }

    # Set the variables used in the loop
    foreach ($Subid in $SubIds) {
      if ([string]::IsNullOrEmpty($subid.name)) {
        # If the variable was set in the Subscription File only IDs will be available
        $Subid = $Subid
        $SubName = $Subid
      }
      else {
        # If using the variable set during the login to Azure, Subscription Name is available
        $SubName = $Subid.Name
        $Subid = $Subid.id
      }
      Write-Host "---------------------------------------------------------------------"
      Write-Host "Validating Subscription: " -NoNewline
      Write-Host $SubName -ForegroundColor Cyan

      Set-AzContext -Subscription $Subid -ErrorAction SilentlyContinue -WarningAction SilentlyContinue | Out-Null

      #Write-Host "Collecting: " -NoNewline
      #Write-Host "Advisories" -ForegroundColor Magenta
      #Advisory $Subid

      Write-Host "----------------------------"
      Write-Host "Collecting: " -NoNewline
      Write-Host "Retirements" -ForegroundColor Magenta
      Retirement $Subid

      Write-Host "----------------------------"
      Write-Host "Collecting: " -NoNewline
      Write-Host "Service Health Alerts" -ForegroundColor Magenta
      ServiceHealth $Subid


      if (![string]::IsNullOrEmpty($ResourceGroups)) {
        $resultAllResourceTypes = @()
        foreach ($RG in $ResourceGroups) {
          $resultAllResourceTypes += Search-AzGraph -Query "resources | where resourceGroup contains '$RG' | summarize count() by type, subscriptionId" -Subscription $Subid
        }
        $Global:AllResourceTypes += $resultAllResourceTypes
      }
      else {
        # Extract and display resource types with the query with subscriptions, we need this to filter the subscriptions later
        $resultAllResourceTypes = Search-AzGraph -Query "resources | summarize count() by type, subscriptionId" -Subscription $Subid
        $Global:AllResourceTypes += $resultAllResourceTypes
      }

      # Create the arrays used to store the kusto queries
      $kqlQueryMap = @{}
      $aprlKqlFiles = @()
      $GluedTypes = @()

      # Validates if queries are applicable based on Resource Types present in the current subscription
      $RootTypes = Get-ChildItem -Path "$clonePath\azure-resources\" -Directory
      foreach ($RootType in $RootTypes) {
        $RootName = $RootType.Name
        $SubTypes = Get-ChildItem -Path $RootType -Directory
        foreach ($SubDir in $SubTypes) {
          $SubDirName = $SubDir.Name
          $GlueType = ('Microsoft.' + $RootName + '/' + $SubDirName)
          if ($GlueType -in $resultAllResourceTypes.type) {
            $aprlKqlFiles += Get-ChildItem -Path $SubDir -Filter "*.kql" -Recurse
            $GluedTypes += $GlueType.ToLower()
          }
        }
      }

      # Populates the QueryMap hashtable
      foreach ($aprlKqlFile in $aprlKqlFiles) {
        $kqlShort = [string]$aprlKqlFile.FullName.split('\')[-1]
        $kqlName = $kqlShort.split('.')[0]

        # Create APRL query map based on recommendation
        $kqlQueryMap[$kqlName] = $aprlKqlFile
      }

      if ($Global:RunbookQueryOverrides) {
        foreach ($queryOverridePath in $($Global:RunbookQueryOverrides)) {
          Write-Host "Loading [$($queryOverridePath)] query overrides..." -ForegroundColor Cyan

          $overrideKqlFiles = Get-ChildItem -Path $queryOverridePath -Filter "*.kql" -Recurse

          foreach ($overrideKqlFile in $overrideKqlFiles) {
            $kqlShort = [string]$overrideKqlFile.FullName.split('\')[-1]
            $kqlName = $kqlShort.split('.')[0]

            Write-Host "Override KQL file: $kqlName"

            if ($kqlQueryMap.ContainsKey($kqlName)) {
              Write-Host "Original [$kqlName] APRL query overridden by [$($overrideKqlFile.FullName)]." -ForegroundColor Yellow
            }

            # Override APRL query map based on recommendation
            $kqlQueryMap[$kqlName] = $overrideKqlFile
          }
        }
      }

      $kqlFiles = $kqlQueryMap.Values

      $queries = @()
      # Loop through each KQL file and execute the queries
      foreach ($kqlFile in $kqlFiles) {
        $kqlshort = [string]$kqlFile.FullName.split('\')[-1]

        $kqlname = $kqlshort.split('.')[0]

        # Read the query content from the file
        $baseQuery = Get-Content -Path $kqlFile.FullName | Out-String
        $typeRaw = $kqlFile.DirectoryName.split('\')
        $kqltype = ($typeRaw[-3] + '/' + $typeRaw[-2])

        $checkId = $kqlname.Split("/")[-1].ToLower()

        if ($Global:RunbookChecks -and $Global:RunbookChecks.Count -gt 0) {
          # A runbook has been provided...

          if ($Global:RunbookChecks.ContainsKey($checkId)) {
            # A check has been configured in the runbook for this query...

            $check = $Global:RunbookChecks[$checkId]

            $check.PSObject.Properties | ForEach-Object {
              $checkName = $_.Name
              $selectorName = $_.Value

              if ($Global:RunbookSelectors.ContainsKey($selectorName)) {
                # If a matching selector exists, add a new query to the queries array
                # that includes the appropriate selector...

                $selector = $Global:RunbookSelectors[$selectorName]

                # First, resolve any // selectors in the query...

                $selectorQuery = $baseQuery.Replace("// selector", "| where $selector")

                # Then, wrap the entire query in an inner join to apply a global selector.
                # With this approach, queries that implement the APRL interface
                # (projecting the recId, id, tags, etc.) columns can be refined using
                # selectors without any changes to the original query. The original query
                # is wrapped in an inner join that limits the results to only those that
                # match the selector.

                $selectorQuery = "resources " `
                  + " | where $selector " `
                  + " | project id " `
                  + " | join kind=inner ( " `
                  + " $selectorQuery ) on id " `
                  + " | project-away id1"

                $queries += [PSCustomObject]@{
                  checkId   = [string]$checkId
                  checkName = [string]$checkName
                  selector  = [string]$selectorName
                  query     = [string]$selectorQuery
                  type      = $null
                }
              }
              else {
                Write-Host "Selector $selectorName not found in runbook. Skipping check..." -ForegroundColor Yellow
              }
            }
          }

          if ($queries.Count -gt 0) {
            Write-Host "There are $($queries.Count.ToString()) runbook checks configured for $checkId. Running checks..." -ForegroundColor Green
          }
        }
        else {
          # A runbook hasn't been configured. The queries array will contain
          # just one element -- the original query. No selectors.

          $queries += [PSCustomObject]@{
            checkId   = [string]$checkId
            checkName = [string]$null
            selector  = "APRL"
            query     = [string]$baseQuery
            type      = [string]$kqltype
          }
        }
      }

      foreach ($queryDef in $queries) {
        $checkId = $queryDef.checkId
        $checkName = $queryDef.checkName
        $query = $queryDef.query
        $selector = $queryDef.selector
        $type = $queryDef.type

        Write-Host "++++++++++++++++++ " -NoNewline
        if ($selector -eq 'APRL') {
          Write-Host "[APRL]: Microsoft.$type - $checkId" -ForegroundColor Green -NoNewline
        }
        else {
          Write-Host "[$selector]: $checkId" -ForegroundColor Green -NoNewline
        }
        Write-Host " +++++++++++++++"

        # Validating if Query is Under Development
        if ($query -match "development") {
          Write-Host "Query $kqlshort under development - Validate Recommendation manually" -ForegroundColor Yellow
          $query = "resources | where type contains '$type' | project name,id,tags"
          QueryCollector $Subid $type $query $checkId $checkName 'Query under development - Validate Recommendation manually'
        }
        elseif ($query -match "cannot-be-validated-with-arg") {
          Write-Host "IMPORTANT - Recommendation $checkId cannot be validated with ARGs - Validate Resources manually" -ForegroundColor Yellow
          $query = "resources | where type contains '$type' | project name,id,tags"
          QueryCollector $Subid $type $query $checkId $checkName 'IMPORTANT - Recommendation cannot be validated with ARGs - Validate Resources manually'
        }
        else {
          QueryCollector $Subid $type $query $checkId $checkName 'Azure Resource Graph'
        }
      }
      #After processing the ARG Queries, now is time to process the -ResourceGroups
      if (![string]::IsNullOrEmpty($ResourceGroups)) {
        $TempResult = $Global:results
        $Global:results = @()

        foreach ($result in $TempResult) {
          $res = $result.id.split('/')
          if ($res[4] -in $ResourceGroups) {
            $Global:results += $result
          }
          if ($result.name -eq "Query under development - Validate Recommendation manually") {
            $Global:results += $result
          }
        }
      }

      #Store all resourcetypes not in APRL
      foreach ($ResType in $GluedTypes) {
        $type = $ResType
        Write-Host "Type $type Not Available In APRL - Validate Service manually" -ForegroundColor Yellow
        $result = [PSCustomObject]@{
          validationAction = 'Service Not Available In APRL - Validate Service manually if Applicable, if not Delete this line'
          recommendationId = $type
          name             = ""
          id               = ""
          tags             = ""
          param1           = ""
          param2           = ""
          param3           = ""
          param4           = ""
          param5           = ""
          checkName        = ""
          selector         = "APRL"
        }
        $Global:results += $result
      }
    }
  }

  function ResourceTypes {
    $TempTypes = $Global:results | Where-Object { $_.name -eq 'Service Not Available In APRL - Validate Service manually if Applicable, if not Delete this line' }
    $Global:AllResourceTypes = $Global:AllResourceTypes | Sort-Object -Property Count_ -Descending
    foreach ($result in $Global:AllResourceTypes) {
      if ($result.type -in $TempTypes.recommendationId) {
        $SubName = ''
        $SubName = ($SubIds | Where-Object { $_.Id -eq $result.subscriptionId }).Name
        $tmp = [PSCustomObject]@{
          'Subscription'        = [string]$SubName
          'Resource Type'       = [string]$result.type
          'Number of Resources' = [string]$result.count_
          'Available in APRL?'  = "No"
          'Custom1'             = ""
          'Custom2'             = ""
          'Custom3'             = ""
        }
        $Global:AllResourceTypesOrdered += $tmp
      }
      else {
        $SubName = ''
        $SubName = ($SubIds | Where-Object { $_.Id -eq $result.subscriptionId }).Name
        $tmp = [PSCustomObject]@{
          'Subscription'        = [string]$SubName
          'Resource Type'       = [string]$result.type
          'Number of Resources' = [string]$result.count_
          'Available in APRL?'  = "Yes"
          'Custom1'             = ""
          'Custom2'             = ""
          'Custom3'             = ""
        }
        $Global:AllResourceTypesOrdered += $tmp
      }
    }
  }

  function Advisory {
    Param($Subid)
    if (![string]::IsNullOrEmpty($ResourceGroups)) {
      $Advisories = @()
      foreach ($RG in $ResourceGroups) {
        $Advisories = Search-AzGraph -Query "advisorresources | where type == 'microsoft.advisor/recommendations' and tostring(properties.category) == 'HighAvailability' | where resourceGroup contains '$RG' | summarize count()" -Subscription $Subid
        if ($Advisories.count_ -lt 1000) {
          $advquery = "advisorresources | where type == 'microsoft.advisor/recommendations' and tostring(properties.category) == 'HighAvailability' | where resourceGroup contains '$RG' | order by id"
          $queryResults += Search-AzGraph -Query $advquery -First 1000 -Subscription $Subid -ErrorAction SilentlyContinue

          foreach ($row in $queryResults) {
            #Write-Host "New result: $row"

            if (![string]::IsNullOrEmpty($row.properties.resourceMetadata.resourceId)) {
              $result = [PSCustomObject]@{
                recommendationId = [string]$row.properties.recommendationTypeId
                type             = [string]$row.Properties.impactedField
                name             = [string]$row.properties.impactedValue
                id               = [string]$row.properties.resourceMetadata.resourceId
                category         = [string]$row.properties.category
                impact           = [string]$row.properties.impact
                description      = [string]$row.properties.shortDescription.solution
              }
              $Global:AllAdvisories += $result
            }
          }
        }
        else {
          $Loop = $Advisories.count_ / 1000
          $Loop = [math]::ceiling($Loop)
          $Looper = 0
          $Limit = 1

          while ($Looper -lt $Loop) {

            $advquery = "advisorresources | where type == 'microsoft.advisor/recommendations' and tostring(properties.category) == 'HighAvailability' | where resourceGroup contains '$RG' | order by id"
            $queryResults = Search-AzGraph -Query $advquery -Subscription $Subid -Skip $Limit -first 1000 -ErrorAction SilentlyContinue
            foreach ($row in $queryResults) {

              if (![string]::IsNullOrEmpty($row.properties.resourceMetadata.resourceId)) {
                $result = [PSCustomObject]@{
                  recommendationId = [string]$row.properties.recommendationTypeId
                  type             = [string]$row.Properties.impactedField
                  name             = [string]$row.properties.impactedValue
                  id               = [string]$row.properties.resourceMetadata.resourceId
                  category         = [string]$row.properties.category
                  impact           = [string]$row.properties.impact
                  description      = [string]$row.properties.shortDescription.solution
                }
                $Global:AllAdvisories += $result
              }
            }
            $Looper ++
            $Limit = $Limit + 1000
          }
        }
      }
    }
    else {
      $Advisories = Search-AzGraph -Query "advisorresources | where type == 'microsoft.advisor/recommendations' and tostring(properties.category) == 'HighAvailability' | summarize count()" -Subscription $Subid

      if ($Advisories.count_ -lt 1000) {
        # Execute the query and collect the results
        $advquery = "advisorresources | where type == 'microsoft.advisor/recommendations' and tostring(properties.category) == 'HighAvailability' | order by id"
        $queryResults = Search-AzGraph -Query $advquery -First 1000 -Subscription $Subid -ErrorAction SilentlyContinue

        foreach ($row in $queryResults) {
          if (![string]::IsNullOrEmpty($row.properties.resourceMetadata.resourceId)) {
            $result = [PSCustomObject]@{
              recommendationId = [string]$row.properties.recommendationTypeId
              type             = [string]$row.Properties.impactedField
              name             = [string]$row.properties.impactedValue
              id               = [string]$row.properties.resourceMetadata.resourceId
              category         = [string]$row.properties.category
              impact           = [string]$row.properties.impact
              description      = [string]$row.properties.shortDescription.solution
            }
            $Global:AllAdvisories += $result
          }
        }
      }
      else {
        $Loop = $Advisories.count_ / 1000
        $Loop = [math]::ceiling($Loop)
        $Looper = 0
        $Limit = 1

        while ($Looper -lt $Loop) {

          $advquery = "advisorresources | where type == 'microsoft.advisor/recommendations' and tostring(properties.category) == 'HighAvailability' | order by id"
          $queryResults = Search-AzGraph -Query $advquery -Subscription $Subid -Skip $Limit -first 1000 -ErrorAction SilentlyContinue
          foreach ($row in $queryResults) {

            if (![string]::IsNullOrEmpty($row.properties.resourceMetadata.resourceId)) {
              $result = [PSCustomObject]@{
                recommendationId = [string]$row.properties.recommendationTypeId
                type             = [string]$row.Properties.impactedField
                name             = [string]$row.properties.impactedValue
                id               = [string]$row.properties.resourceMetadata.resourceId
                category         = [string]$row.properties.category
                impact           = [string]$row.properties.impact
                description      = [string]$row.properties.shortDescription.solution
              }
              $Global:AllAdvisories += $result
            }
          }
          $Looper ++
          $Limit = $Limit + 1000
        }
      }
    }
  }

  function Retirement {
    param($Subid)

    $RetirementCount = Search-AzGraph -Query "servicehealthresources | where properties.EventSubType contains 'Retirement' | summarize count()" -Subscription $Subid
    if ($RetirementCount.count_ -lt 1000) {
      $retquery = "servicehealthresources | where properties.EventSubType contains 'Retirement' | order by id"
      $queryResults = Search-AzGraph -Query $retquery -First 1000 -Subscription $Subid -ErrorAction SilentlyContinue

      foreach ($row in $queryResults) {
        $OutagesRetired = $Global:RetiredOutages | Where-Object { $_.name -eq $row.properties.TrackingId }

        $result = [PSCustomObject]@{
          Subscription    = [string]$Subid
          TrackingId      = [string]$row.properties.TrackingId
          Status          = [string]$row.Properties.Status
          LastUpdateTime  = [string]$OutagesRetired.properties.lastUpdateTime
          Endtime         = [string]$OutagesRetired.properties.impactMitigationTime
          Level           = [string]$row.properties.Level
          Title           = [string]$row.properties.Title
          Summary         = [string]$row.properties.Summary
          Header          = [string]$row.properties.Header
          ImpactedService = [string]$row.properties.Impact.ImpactedService
          Description     = [string]$OutagesRetired.properties.description
        }
        $Global:AllRetirements += $result
      }
    }
    else {
      $Loop = $RetirementCount.count_ / 1000
      $Loop = [math]::ceiling($Loop)
      $Looper = 0
      $Limit = 1

      while ($Looper -lt $Loop) {
        $retquery = "servicehealthresources | where properties.EventSubType contains 'Retirement' | order by id"
        $queryResults = Search-AzGraph -Query $retquery -Subscription $Subid -Skip $Limit -first 1000 -ErrorAction SilentlyContinue

        foreach ($row in $queryResults) {
          $OutagesRetired = $Global:RetiredOutages | Where-Object { $_.name -eq $row.properties.TrackingId }

          $result = [PSCustomObject]@{
            Subscription    = [string]$Subid
            TrackingId      = [string]$row.properties.TrackingId
            Status          = [string]$row.Properties.Status
            LastUpdateTime  = [string]$OutagesRetired.properties.lastUpdateTime
            Endtime         = [string]$OutagesRetired.properties.impactMitigationTime
            Level           = [string]$row.properties.Level
            Title           = [string]$row.properties.Title
            Summary         = [string]$row.properties.Summary
            Header          = [string]$row.properties.Header
            ImpactedService = [string]$row.properties.Impact.ImpactedService
            Description     = [string]$OutagesRetired.properties.description
          }
          $Global:AllRetirements += $result
        }
      }
    }
  }

  function ServiceHealth {
    param($Subid)

    $ServiceHealthCount = Search-AzGraph -Query "resources | where type == 'microsoft.insights/activitylogalerts' | summarize count()" -Subscription $Subid
    if ($ServiceHealthCount.count_ -lt 1000) {
      $Servicequery = "resources | where type == 'microsoft.insights/activitylogalerts' | order by id"
      $queryResults = Search-AzGraph -Query $Servicequery -First 1000 -Subscription $Subid -ErrorAction SilentlyContinue

      $Rowler = @()
      foreach ($row in $queryResults) {
        foreach ($type in $row.properties.condition.allOf) {
          if ($type.equals -eq 'ServiceHealth') {
            $Rowler += $row
          }
        }
      }

      foreach ($Row in $Rowler) {
        $SubName = ($SubIds | Where-Object { $_.Id -eq ($Row.properties.scopes.split('/')[2]) }).Name
        $PreRegion = $Row.Properties.condition.allOf | Where-Object { $_.field -eq 'properties.impactedServices[*].ImpactedRegions[*].RegionName' }
        $PreService = $Row.Properties.condition.allOf | Where-Object { $_.field -eq 'properties.impactedServices[*].ServiceName' }
        $PreEventType = $Row.Properties.condition.allOf.anyOf | Select-Object -Property equals | ForEach-Object { switch ($_.equals) { 'Incident' { 'Service Issues' } 'Informational' { 'Health Advisories' } 'ActionRequired' { 'Security Advisory' } 'Maintenance' { 'Planned Maintenance' } } }
        if (![string]::IsNullOrEmpty($PreEventType)) { $EventType = $Row.Properties.condition.allOf.anyOf | Select-Object -Property equals | ForEach-Object { switch ($_.equals) { 'Incident' { 'Service Issues' } 'Informational' { 'Health Advisories' } 'ActionRequired' { 'Security Advisory' } 'Maintenance' { 'Planned Maintenance' } } } } Else { $EventType = 'All' }
        if (![string]::IsNullOrEmpty($PreService)) { $Services = $Row.Properties.condition.allOf | Where-Object { $_.field -eq 'properties.impactedServices[*].ServiceName' } | Select-Object -Property containsAny | ForEach-Object { $_.containsAny } } Else { $Services = 'All' }
        if (![string]::IsNullOrEmpty($PreRegion)) { $Regions = $Row.Properties.condition.allOf | Where-Object { $_.field -eq 'properties.impactedServices[*].ImpactedRegions[*].RegionName' } | Select-Object -Property containsAny | ForEach-Object { $_.containsAny } }Else { $Regions = 'All' }

        $result = [PSCustomObject]@{
          Name         = [string]$row.name
          Subscription = [string]$SubName
          Enabled      = [string]$Row.properties.enabled
          EventType    = $EventType
          Services     = $Services
          Regions      = $Regions
          ActionGroup  = $Row.Properties.actions.actionGroups.actionGroupId.split('/')[8]
        }
        $Global:AllServiceHealth += $result
      }
    }
    else {
      $Loop = $ServiceHealthCount.count_ / 1000
      $Loop = [math]::ceiling($Loop)
      $Looper = 0
      $Limit = 1
      $Rowler = @()

      while ($Looper -lt $Loop) {
        $Servicequery = "resources | where type == 'microsoft.insights/activitylogalerts' | order by id"
        $queryResults = Search-AzGraph -Query $Servicequery -Subscription $Subid -Skip $Limit -first 1000 -ErrorAction SilentlyContinue

        foreach ($row in $queryResults) {
          foreach ($type in $row.properties.condition.allOf) {
            if ($type.equals -eq 'ServiceHealth') {
              $Rowler += $row
            }
          }
        }

      }
      foreach ($Row in $Rowler) {
        $SubName = ($SubIds | Where-Object { $_.Id -eq ($Row.properties.scopes.split('/')[2]) }).Name
        $EventType = $Row.Properties.condition.allOf.anyOf | Select-Object -Property equals | ForEach-Object { switch ($_.equals) { 'Incident' { 'Service Issues' } 'Informational' { 'Health Advisories' } 'ActionRequired' { 'Security Advisories' } 'Maintenance' { 'Planned Maintenance' } } }
        $Services = $Row.Properties.condition.allOf | Where-Object { $_.field -eq 'properties.impactedServices[*].ServiceName' } | Select-Object -Property containsAny | ForEach-Object { $_.containsAny }
        $Regions = $Row.Properties.condition.allOf | Where-Object { $_.field -eq 'properties.impactedServices[*].ImpactedRegions[*].RegionName' } | Select-Object -Property containsAny | ForEach-Object { $_.containsAny }

        $result = [PSCustomObject]@{
          Name         = [string]$row.name
          Subscription = [string]$SubName
          Enabled      = [string]$Row.properties.enabled
          EventType    = if (![string]::IsNullOrEmpty($EventType)) { $EventType }Else { 'All' }
          Services     = if (![string]::IsNullOrEmpty($Services)) { $Services }Else { 'All' }
          Regions      = if (![string]::IsNullOrEmpty($Regions)) { $Regions }Else { 'All' }
          ActionGroup  = $Row.Properties.actions.actionGroups.actionGroupId.split('/')[8]
        }
        $Global:AllServiceHealth += $result
      }
    }
  }

  function JsonFile {
    $ResourceExporter = @{
      Resource = $Global:results
    }
    $ResourceTypeExporter = @{
      ResourceType = $Global:AllResourceTypesOrdered
    }
    $AdvisoryExporter = @{
      Advisory = $Global:AllAdvisories
    }
    $OutageExporter = @{
      Outages = $Global:Outageslist
    }
    $RetirementExporter = @{
      Retirements = $Global:AllRetirements
    }
    $SupportExporter = @{
      SupportTickets = $Global:SupportTickets
    }
    $ServiceHealthExporter = @{
      ServiceHealth = $Global:AllServiceHealth
    }

    $ExporterArray = @()
    $ExporterArray += $ResourceExporter
    $ExporterArray += $ResourceTypeExporter
    $ExporterArray += $AdvisoryExporter
    $ExporterArray += $OutageExporter
    $ExporterArray += $RetirementExporter
    $ExporterArray += $SupportExporter
    $ExporterArray += $ServiceHealthExporter

    $Global:JsonFile = ($PSScriptRoot + "\WARA_File_" + (get-date -Format "yyyy-MM-dd_HH_mm") + ".json")

    $ExporterArray | ConvertTo-Json -Depth 15 | Out-File $Global:JsonFile

  }


  #Call the functions
  $Global:Version = "2.0.6"
  Write-Host "Version: " -NoNewline
  Write-Host $Global:Version -ForegroundColor DarkBlue

  if ($Help.IsPresent) {
    Help
    Exit
  }

  Write-Debug "Checking Parameters"
  CheckParameters

  Write-Debug "Reseting Variables"
  Variables

  Write-Debug "Calling Function: Requirements"
  Requirements

  Write-Debug "Calling Function: LocalFiles"
  LocalFiles

  Write-Debug "Calling Function: Runbook"
  Runbook

  Write-Debug "Calling Function: ConnectToAzure"
  ConnectToAzure

  Write-Debug "Calling Function: Subscriptions"
  Subscriptions

  #Write-Debug "Calling Function: PSExtraction"
  #PSExtraction

  Write-Debug "Calling Function: ResourceExtraction"
  ResourceExtraction

  Write-Debug "Calling Function: ResourceTypes"
  ResourceTypes

  Write-Debug "Calling Function: JsonFile"
  JsonFile

}

$TotalTime = $Global:Runtime.Totalminutes.ToString('#######.##')

Write-Host "---------------------------------------------------------------------"
Write-Host ('Execution Complete. Total Runtime was: ') -NoNewline
Write-Host $TotalTime -NoNewline -ForegroundColor Cyan
Write-Host (' Minutes')
Write-Host "Result File: " -NoNewline
Write-Host $Global:JsonFile -ForegroundColor Blue
Write-Host "---------------------------------------------------------------------"
