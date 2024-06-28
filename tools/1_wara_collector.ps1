[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'False positive as Write-Host does not represent a security risk and this script will always run on host consoles')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '', Justification = 'False positive as parameters are not always required')]

<#
.SYNOPSIS
Well-Architected Reliability Assessment Script

.DESCRIPTION
The script "1_wara_collector" will execute the kusto queries from APRL (Azure Proactive Resiliency Library) against an Azure Environment and will export the results to a JSON file.

.LINK
https://github.com/Azure/Azure-Proactive-Resiliency-Library-v2

#>

Param(
  [switch]$Debugging,
  [switch]$Help,
  [switch]$SAP,
  [switch]$AVD,
  [switch]$AVS,
  [switch]$HPC,
  [switch]$UseImplicitRunbookSelectors,
  $RunbookFile,
  $SubscriptionIds,
  $ResourceGroups,
  $TenantID,
  $Tags,
  [ValidateSet('AzureCloud', 'AzureUSGovernment')]
  $AzureEnvironment = 'AzureCloud',
  $ConfigFile
  )

#import-module "./modules/collector.psm1" -Force

$Script:ShellPlatform = $PSVersionTable.Platform

if ($Tags) {$TagsPresent = $true}else{$TagsPresent = $false}

$Script:Runtime = Measure-Command -Expression {

  Function Get-AllAzGraphResource {
    param (
      [string[]]$subscriptionId,
      [string]$query = 'Resources | project id, resourceGroup, subscriptionId, name, type, location'
    )

    $result = $subscriptionId ? (Search-AzGraph -Query $query -first 1000 -Subscription $subscriptionId) : (Search-AzGraph -Query $query -first 1000 -usetenantscope) # -first 1000 returns the first 1000 results and subsequently reduces the amount of queries required to get data.

    # Collection to store all resources
    $allResources = @($result)

    # Loop to paginate through the results using the skip token
    while ($result.SkipToken) {
      # Retrieve the next set of results using the skip token
      $result = $subscriptionId ? (Search-AzGraph -Query $query -SkipToken $result.SkipToken -Subscription $subscriptionId -First 1000) : (Search-AzGraph -query $query -SkipToken $result.SkipToken -First 1000 -UseTenantScope)
      # Add the results to the collection
      $allResources += $result
    }

    # Output all resources
    return $allResources
  }

  function Get-AllResourceGroup {
    param (
      [string[]]$SubscriptionIds
    )

    # Query to get all resource groups in the tenant
    $q = "resourcecontainers
    | where type == 'microsoft.resources/subscriptions'
    | project subscriptionId, subscriptionName = name
    | join (resourcecontainers
        | where type == 'microsoft.resources/subscriptions/resourcegroups')
        on subscriptionId
    | project subscriptionName, subscriptionId, resourceGroup, id=tolower(id)"

    $r = $SubscriptionIds ? (Get-AllAzGraphResource -query $q -subscriptionId $SubscriptionIds -usetenantscope) : (Get-AllAzGraphResource -query $q -usetenantscope)

    # Returns the resource groups
    return $r
  }

  function Import-ConfigFileData($file){
    # Read the file content and store it in a variable
    $filecontent = (Get-content $file).trim().tolower()

    # Create an array to store the line number of each section
    $linetable = @()
    $objarray = @{}

    # Iterate through the file content and store the line number of each section
    Foreach($line in $filecontent){
        if (-not [string]::IsNullOrWhiteSpace($line) -and -not $line.startswith("#")){
            # If the line is a section, store the line number
            if ($line -match "^\[([^\]]+)\]$") {
                # Store the section name and line number. Remove the brackets from the section name
                $linetable += $filecontent.indexof($line)

            }
        }
    }

    # Iterate through the line numbers and extract the section content
    $count = 0
    foreach($entry in $linetable){

        # Get the section name
        $name = $filecontent[$entry]
        # Remove the brackets from the section name
        $name = $name.replace("[","").replace("]","")

        # Get the start and stop line numbers for the section content
        # If the section is the last one, set the stop line number to the end of the file
        $start = $entry + 1
        if($count -eq ($linetable.length-1)){
            $stop = $filecontent.length - 1
        }
        else{
            $stop = $linetable[$count+1] - 2
        }

        # Extract the section content
        $configsection = $filecontent[$start..$stop]

        # Add the section content to the object array
        $objarray += @{$Name=$configsection}

        # Increment the count
        $count++
    }

    # Return the object array and cast to pscustomobject
    return [pscustomobject]$objarray

  }

  function Get-ResourceGroupsByList {
    param (
      [Parameter(Mandatory = $true)]
      [array]$ObjectList,

      [Parameter(Mandatory = $true)]
      [array]$FilterList,

      [Parameter(Mandatory = $true)]
      [string]$KeyColumn
    )

    $matchingObjects = @()

    foreach ($obj in $ObjectList) {
      if (($obj.$KeyColumn.split('/')[0..4] -join '/') -in $FilterList) {
        $matchingObjects += $obj
      }
    }

    return $matchingObjects
  }

  function Test-SubscriptionParameter {
    if ([string]::IsNullOrEmpty($SubscriptionIds) -and [string]::IsNullOrEmpty($ConfigFile))
      {
        Write-Host ""
        Write-Host "Suscription ID or Subscription File is required"
        Write-Host ""
        Exit
      }
  }

  function Get-HelpMessage {
    Write-Host ""
    Write-Host "Parameters"
    Write-Host ""
    Write-Host " -TenantID <ID>        :  Optional; tenant to be used. "
    Write-Host " -SubscriptionIds <IDs>:  Optional (or SubscriptionsFile); Specifies Subscription(s) to be included in the analysis: Subscription1,Subscription2. "
    Write-Host " -SubscriptionsFile    :  Optional (or SubscriptionIds); specifies the file with the subscription list to be analysed (one subscription per line). "
    Write-Host " -RunbookFile          :  Optional; specifies the file with the runbook (selectors & checks) to be used. "
    Write-Host " -ResourceGroups       :  Optional; specifies Resource Group(s) to be included in the analysis: ResourceGroup1,ResourceGroup2. "
    Write-Host " -SAP                  :  Optional; gets specialized recommendations and queries for the defined workload form the APRL - Specialized Workloads section. "
    Write-Host " -AVD                  :  Optional; gets specialized recommendations and queries for the defined workload form the APRL - Specialized Workloads section. "
    Write-Host " -AVS                  :  Optional; gets specialized recommendations and queries for the defined workload form the APRL - Specialized Workloads section. "
    Write-Host " -HPC                  :  Optional; gets specialized recommendations and queries for the defined workload form the APRL - Specialized Workloads section. "
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
    Write-Host ''
    Write-Host ''
  }

  function Invoke-ResetVariable {
    $Script:SubIds = ''
    $Script:AllResourceTypes = @()
    $Script:SupportedResTypes = @()
    $Script:AllResourceTypesOrdered = @()
    $Script:AllAdvisories = @()
    $Script:AllRetirements = @()
    $Script:AllServiceHealth = @()
    $Script:results = @()
    $Script:InScope = @()
    $Script:OutOfScope = @()
    $Script:PreInScopeResources = @()
    $Script:PreOutOfScopeResources = @()
    $Script:TaggedResources = @()
    $Script:AdvisorTypes = @()


    # Runbook stuff
    $Script:RunbookChecks = @{}
    $Script:RunbookParameters = @{}
    $Script:RunbookQueryOverrides = @()
    $Script:RunbookSelectors = @{}
  }

  function Test-Requirement {
    # Install required modules
    try
      {
        Write-Host "Validating " -NoNewline
        Write-Host "Az.ResourceGraph" -ForegroundColor Cyan -NoNewline
        Write-Host " Module.."
        $AzModules = Get-Module -Name Az.ResourceGraph -ListAvailable -ErrorAction silentlycontinue
        if ($null -eq $AzModules)
          {
            Write-Host "Installing Az Modules" -ForegroundColor Yellow
            Install-Module -Name Az.ResourceGraph -SkipPublisherCheck -InformationAction SilentlyContinue
          }
        <#
        Write-Host "Validating " -NoNewline
        Write-Host "Microsoft.PowerShell.ConsoleGuiTools" -ForegroundColor Cyan -NoNewline
        Write-Host " Module.."
        $ConsoleGUITools = Get-Module -Name Microsoft.PowerShell.ConsoleGuiTools -ListAvailable -ErrorAction silentlycontinue
        if ($null -eq $ConsoleGUITools)
          {
            Write-Host "Installing ConsoleGuiTools Modules" -ForegroundColor Yellow
            Install-Module -Name Microsoft.PowerShell.ConsoleGuiTools -SkipPublisherCheck -InformationAction SilentlyContinue
          }
        #>
        Write-Host "Validating " -NoNewline
        Write-Host "Git" -ForegroundColor Cyan -NoNewline
        Write-Host " Installation.."
        $GitVersion = git --version
        if ($null -eq $GitVersion)
          {
            Write-Host "Missing Git" -ForegroundColor Red
            Exit
          }
        $Script:ScriptData = [pscustomobject]@{
            Version             = $Script:Version
            SAP                 = if($SAP.IsPresent){$true}else{$false}
            AVD                 = if($AVD.IsPresent){$true}else{$false}
            AVS                 = if($AVS.IsPresent){$true}else{$false}
            HPC                 = if($HPC.IsPresent){$true}else{$false}
            Debugging           = if($Debugging.IsPresent){$true}else{$false}
            ConfigFile          = if($ConfigFile){$true}else{$false}
            ConfigFileTenant    = if($ConfigFile){$TenantID}else{$false}
            ConfigFileScopes    = if($ConfigFile){$Scopes}else{$false}
            ConfigFilelocations = if($ConfigFile){$locations}else{$false}
            ConfigFileTags      = if($ConfigFile){$Tags}else{$false}
            SubscriptionIds     = if($SubscriptionIds){$SubscriptionIds}else{$false}
            ResourceGroups      = if($ResourceGroups){$ResourceGroups}else{$false}
            Tags                = if($TagsPresent){$Tags}else{$false}
          }
      }
    catch
      {
        # Report Error
        $errorMessage = $_.Exception.Message
        Write-Host "Error executing function Requirements: $errorMessage" -ForegroundColor Red
      }
  }

  function Set-LocalFile {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
    param()

    if ($PSCmdlet.ShouldProcess('')) {
      Write-Debug 'Setting local path'
      try {
        # Clone the GitHub repository to a temporary folder
        $repoUrl = 'https://github.com/Azure/Azure-Proactive-Resiliency-Library-v2'

        # Define script path as the default path to save files
        $workingFolderPath = $PSScriptRoot
        Set-Location -Path $workingFolderPath;
        if ($Script:ShellPlatform -eq 'Win32NT') {
          $Script:clonePath = "$workingFolderPath\Azure-Proactive-Resiliency-Library"
        } else {
          $Script:clonePath = "$workingFolderPath/Azure-Proactive-Resiliency-Library"
        }
        Write-Debug 'Checking default folder'
        if ((Get-ChildItem -Path $Script:clonePath -Force -ErrorAction SilentlyContinue | Measure-Object).Count -gt 0) {
          Write-Debug 'APRL Folder does exist. Reseting it...'
          Get-Item -Path $Script:clonePath | Remove-Item -Recurse -Force
          git clone $repoUrl $clonePath --quiet
        } else {
          git clone $repoUrl $clonePath --quiet
        }
        Write-Debug 'Checking the version of the script'
        if ($Script:ShellPlatform -eq 'Win32NT') {
          $RepoVersion = Get-Content -Path "$clonePath/tools/Version.json" -ErrorAction SilentlyContinue | ConvertFrom-Json
        } else {
          $RepoVersion = Get-Content -Path "$clonePath\tools\Version.json" -ErrorAction SilentlyContinue | ConvertFrom-Json
        }
        if ($Version -ne $RepoVersion.Collector) {
          Write-Host 'This version of the script is outdated. ' -BackgroundColor DarkRed
          Write-Host 'Please use a more recent version of the script.' -BackgroundColor DarkRed
        } else {
          Write-Host 'This version of the script is current version. ' -BackgroundColor DarkGreen
        }

        # Validates if queries are applicable based on Resource Types present in the current subscription
        if ($Script:ShellPlatform -eq 'Win32NT') {
          $RootTypes = Get-Content -Path "$clonePath\tools\WARAinScopeResTypes.csv" | ConvertFrom-Csv
        } else {
          $RootTypes = Get-Content -Path "$clonePath/tools/WARAinScopeResTypes.csv" | ConvertFrom-Csv
        }
        $Script:SupportedResTypes = (($RootTypes | Where-Object {$_.WARAinScope -eq 'yes'}).ResourceType).tolower()
        $Script:AdvisorTypes = (($RootTypes | Where-Object {$_.inAprlAndOrAdvisor -eq 'yes'}).ResourceType).tolower()
      } catch {
        # Report Error
        $errorMessage = $_.Exception.Message
        Write-Host "Error executing function LocalFiles: $errorMessage" -ForegroundColor Red
      }
    }
  }

  function Connect-ToAzure {
    $Subscription0 = $Scopes | Select-Object -First 1 | ForEach-Object {$_.split("/")[2]}
    # Connect To Azure Tenant
    Write-Host 'Authenticating to Azure'
    if ($Script:ShellPlatform -eq 'Win32NT') {
      Clear-AzContext -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue -InformationAction SilentlyContinue
      if ([string]::IsNullOrEmpty($TenantID)) {
        Write-Host 'Tenant ID not specified.'
        Write-Host ''
        Connect-AzAccount -WarningAction SilentlyContinue -Environment $AzureEnvironment
        $Tenants = Get-AzTenant
        if ($Tenants.count -gt 1) {
          Write-Host 'Select the Azure Tenant to connect : '
          $Selection = 1
          foreach ($Tenant in $Tenants) {
            $TenantName = $Tenant.Name
            Write-Host "$Selection)  $TenantName"
            $Selection ++
          }
          Write-Host ''
          [int]$SelectedTenant = Read-Host 'Select Tenant'
          $defaultTenant = --$SelectedTenant
          $TenantID = $Tenants[$defaultTenant]
          Connect-AzAccount -Tenant $TenantID -Subscription $Subscription0 -WarningAction SilentlyContinue -Environment $AzureEnvironment
        }
      } else {
        Connect-AzAccount -Tenant $TenantID -Subscription $Subscription0 -WarningAction SilentlyContinue -Environment $AzureEnvironment
      }
      #Set the default variable with the list of subscriptions in case no Subscription File was informed
      $Script:SubIds = Get-AzSubscription -TenantId $TenantID -WarningAction SilentlyContinue
    } else {
      Connect-AzAccount -Identity -Environment $AzureEnvironment
      $Script:SubIds = Get-AzSubscription -WarningAction SilentlyContinue
    }
  }

  function Test-Runbook {
    # Checks if a runbook file was provided and, if so, loads selectors and checks hashtables
    if (![string]::IsNullOrEmpty($RunbookFile)) {

      Write-Host '[Runbook]: A runbook has been configured. Only checks configured in the runbook will be run.' -ForegroundColor Cyan

      # Check that the runbook file actually exists
      if (Test-Path $RunbookFile -PathType Leaf) {

        # Try to load runbook JSON
        $RunbookJson = Get-Content -Raw $RunbookFile | ConvertFrom-Json

        # Try to load parameters
        $RunbookJson.parameters.PSObject.Properties | ForEach-Object {
          $Script:RunbookParameters[$_.Name] = $_.Value
        }

        # Try to load selectors
        $RunbookJson.selectors.PSObject.Properties | ForEach-Object {
          $Script:RunbookSelectors[$_.Name.ToLower()] = $_.Value
        }

        # Try to load checks
        $RunbookJson.checks.PSObject.Properties | ForEach-Object {
          $Script:RunbookChecks[$_.Name.ToLower()] = $_.Value
        }

        # Try to load query overrides
        $RunbookJson.query_overrides | ForEach-Object {
          $Script:RunbookQueryOverrides += [string]$_
        }
      }
    } else {
      Write-Host '[Runbook]: No runbook (-RunbookFile) configured.' -ForegroundColor DarkGray
    }
  }

  <# function Invoke-PSModule {
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
          $ScriptName = $Script.Name.Substring(0, $Script.Name.length - '.ps1'.length)
          $ScriptFull = New-Object System.IO.StreamReader($Script.FullName)
          $ScriptReady = $ScriptFull.ReadToEnd()
          $ScriptFull.Dispose()

          if ($ScriptReady -like '# Azure PowerShell script*') {
            $ViableScripts += $Script
            New-Variable -Name ('ScriptRun_' + $ScriptName) #-ErrorAction SilentlyContinue
            New-Variable -Name ('ScriptJob_' + $ScriptName) #-ErrorAction SilentlyContinue
            Set-Variable -Name ('ScriptRun_' + $ScriptName) -Value ([PowerShell]::Create()).AddScript($ScriptReady).AddArgument($($args[2])).AddArgument($($args[0]))
            Set-Variable -Name ('ScriptJob_' + $ScriptName) -Value ((Get-Variable -Name ('ScriptRun_' + $ScriptName)).Value).BeginInvoke()
            $job += (Get-Variable -Name ('ScriptJob_' + $ScriptName)).Value
          }
        }

        while ($Job.Runspace.IsCompleted -contains $false) { Start-Sleep -Milliseconds 100 }

        foreach ($Script in $ViableScripts) {
          $ScriptName = $Script.Name.Substring(0, $Script.Name.length - '.ps1'.length)
          New-Variable -Name ('ScriptValue_' + $ScriptName) #-ErrorAction SilentlyContinue
          Set-Variable -Name ('ScriptValue_' + $ScriptName) -Value (((Get-Variable -Name ('ScriptRun_' + $ScriptName)).Value).EndInvoke((Get-Variable -Name ('ScriptJob_' + $ScriptName)).Value))
        }

        $Hashtable = @{}

        foreach ($Script in $ViableScripts) {
          $ScriptName = $Script.Name.Substring(0, $Script.Name.length - '.ps1'.length)
          $Hashtable["$ScriptName"] = (Get-Variable -Name ('ScriptValue_' + $ScriptName)).Value
        }

        $Hashtable
      } -ArgumentList $SubID, $SideScripts, $ResourceGroups

    }

    Write-Debug 'Starting to Process Jobs'
    $JobNames = @()
    Foreach ($Job in (Get-Job | Where-Object { $_.name -like 'PSExtraction_*' })) {
      $JobNames += $Job.Name
    }

    while (Get-Job -Name $JobNames | Where-Object { $_.State -eq 'Running' }) {
      $jb = Get-Job -Name $JobNames
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
              param1           = [string]$data.param1
              param2           = [string]$data.param2
              param3           = [string]$data.param3
              param4           = [string]$data.param4
              param5           = [string]$data.param5
              checkName        = ''
            }
            if (![string]::IsNullOrEmpty($result.recommendationId)) {
              $Script:results += $result
            }
          }
        }
      }
    }

    foreach ($Job in $JobNames) {
      Remove-Job $Job -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    }
  } #>

  function Start-ScopesLoop {
    $Date = (Get-Date).AddMonths(-24)
    $DateOutages = (Get-Date).AddMonths(-3)
    $DateCore = (Get-Date).AddMonths(-3)
    $Date = $Date.ToString('MM/dd/yyyy')
    if ($AzureEnvironment -eq 'AzureUSGovernment') {
      $BaseURL = 'management.usgovcloudapi.net'
    } else {
      $BaseURL = 'management.azure.com'
    }
    $LoopedSub = @()

    foreach ($Scope in $Scopes)
      {
        if (![string]::IsNullOrEmpty($Scope))
          {
            $ScopeWithoutParameter = $Scope.split(" -")[0]
            $ScopeParameters = $Scope.split(" -")
            $ScopeParameters = $ScopeParameters[1..($ScopeParameters.Length-1)]
            $Subscription = $ScopeWithoutParameter.split("/")[2]
            $RGroup = if (![string]::IsNullOrEmpty($ScopeWithoutParameter.split("/")[4])){$ScopeWithoutParameter.split("/")[4]}else{$null}
            $SubId = $SubIds | Where-Object { $_.Id -eq $Subscription }
            Write-Host '---------------------------------------------------------------------'
            Write-Host 'Validating Scope: ' -NoNewline
            Write-Host $ScopeWithoutParameter -ForegroundColor Cyan

            Set-AzContext -Subscription $Subid -ErrorAction SilentlyContinue -WarningAction SilentlyContinue | Out-Null
            Select-AzSubscription -Subscription $Subid -WarningAction SilentlyContinue -InformationAction SilentlyContinue | Out-Null

            if ($SubId -notin $LoopedSub) {
              $Token = Get-AzAccessToken

              $header = @{
                'Authorization' = 'Bearer ' + $Token.Token
              }

              try {
                Write-Host '----------------------------'
                Write-Host 'Collecting: ' -NoNewline
                Write-Host 'Outages' -ForegroundColor Magenta
                $url = ('https://' + $BaseURL + '/subscriptions/' + $Subid + '/providers/Microsoft.ResourceHealth/events?api-version=2022-10-01&queryStartTime=' + $Date)
                $Outages = Invoke-RestMethod -Uri $url -Headers $header -Method GET
                $Script:Outageslist += $Outages.value | Where-Object { $_.properties.impactStartTime -gt $DateOutages } | Sort-Object @{Expression = 'properties.eventlevel'; Descending = $false }, @{Expression = 'properties.status'; Descending = $false } | Select-Object -Property name, properties -First 15
                $Script:RetiredOutages += $Outages.value | Sort-Object @{Expression = 'properties.eventlevel'; Descending = $false }, @{Expression = 'properties.status'; Descending = $false } | Select-Object -Property name, properties
              } catch { $null }

              try {
                Write-Host '----------------------------'
                Write-Host 'Collecting: ' -NoNewline
                Write-Host 'Support Tickets' -ForegroundColor Magenta
                $supurl = ('https://' + $BaseURL + '/subscriptions/' + $Subid + '/providers/Microsoft.Support/supportTickets?api-version=2020-04-01')
                $SupTickets = Invoke-RestMethod -Uri $supurl -Headers $header -Method GET
                $Script:SupportTickets += $SupTickets.value | Where-Object { $_.properties.severity -ne 'Minimal' -and $_.properties.createdDate -gt $DateCore } | Select-Object -Property name, properties
              } catch { $null }
            }

            Write-Host '----------------------------'
            Write-Host 'Collecting: ' -NoNewline
            Write-Host 'Resources Details' -ForegroundColor Magenta
            if ($ScopeWithoutParameter.split("/").count -lt 5)
              {
                $InScopeSub = $ScopeWithoutParameter.split("/")[2]
                $ScopeQuery = "resources | where subscriptionId =~ '$InScopeSub' | project id, resourceGroup, subscriptionId, name, type, location"
              }
            elseif ($ScopeWithoutParameter.split("/").count -gt 4 -and $Scope.split("/").count -lt 8)
              {
                $InScopeSub = $Scope.split("/")[2]
                $InScopeRG = $Scope.split("/")[4]
                $ScopeQuery = "resources | where subscriptionId =~ '$InScopeSub' and resourceGroup =~ '$InScopeRG' | project id, resourceGroup, subscriptionId, name, type, location"
              }
            elseif ($ScopeWithoutParameter.split("/").count -ge 9)
              {
                $ScopeQuery = "resources | where id =~ '$ScopeWithoutParameter' | project id, resourceGroup, subscriptionId, name, type, location"
              }
            #Filter out the Supported Types
            $ScopeResources = Get-AllAzGraphResource -query $ScopeQuery -subscriptionId $Subid
            foreach ($Resource in $ScopeResources)
              {
                if ($Resource.type -in $Script:SupportedResTypes)
                  {
                    $Script:PreInScopeResources += $Resource
                  }
                else
                  {
                    $Script:PreOutOfScopeResources += $Resource
                  }
              }

            if ($Tags) {
              Write-Host '----------------------------'
              Write-Host 'Collecting: ' -NoNewline
              Write-Host 'Tagged Resources' -ForegroundColor Magenta
              Invoke-TagFiltering -Scope $ScopeWithoutParameter
            }

            Write-Host '----------------------------'
            Write-Host 'Collecting: ' -NoNewline
            Write-Host 'Advisor Recommendations' -ForegroundColor Magenta
            Invoke-AdvisoryExtraction -SubId $SubId -ResourceGroup $RGroup

            if ($SubId -notin $LoopedSub) {
              Write-Host '----------------------------'
              Write-Host 'Collecting: ' -NoNewline
              Write-Host 'Service Retirements Notifications' -ForegroundColor Magenta
              Invoke-RetirementExtraction $Subid

              Write-Host '----------------------------'
              Write-Host 'Collecting: ' -NoNewline
              Write-Host 'Service Health Alerts' -ForegroundColor Magenta
              Invoke-ServiceHealthExtraction $Subid
              $LoopedSub += $SubId
            }
            Write-Host '----------------------------'
            Write-Host 'Running: ' -NoNewline
            Write-Host 'Queries' -ForegroundColor Magenta
            Write-Host '----------------------------'
            Start-ResourceExtraction -Scope $ScopeWithoutParameter
          }
      }
  }

  function Invoke-TagFiltering {
    param($Scope)

    $Scope = $Scope.split(" -")[0]
    if ($Scope.split("/").count -lt 5)
      {
        $InScopeSub = $Scope.split("/")[2]
        $ResourceScopeQuery = "resources | where subscriptionId =~ '$InScopeSub' "
        $ContainerScopeQuery = "resourceContainers | where id =~ '$Scope' "
      }
    elseif ($Scope.split("/").count -gt 4 -and $Scope.split("/").count -lt 8)
      {
        $InScopeSub = $Scope.split("/")[2]
        $InScopeRG = $Scope.split("/")[4]
        $ResourceScopeQuery = "resources | where subscriptionId =~ '$InScopeSub' and resourceGroup =~ '$InScopeRG' "
        $ContainerScopeQuery = "resourceContainers | where id =~ '$Scope' "
      }
    elseif ($Scope.split("/").count -ge 9)
      {
        $ResourceScopeQuery = "resources | where id =~ '$Scope' "
        $ContainerScopeQuery = "resourceContainers | where id =~ '$Scope' "
      }

    $TagFilter = $Tags
    $Counter = 0

    # Each line in the Tag Filtering file will be processed
    $AllTaggedResourceGroups = @()
    $AllTaggedResources = @()
    Foreach ($TagLine in $TagFilter) {
      # Finding the TagKey and all the TagValues in the line
      if ($TagLine -like '*==*')
        {
          $TagKeys = $TagLine.split('==')[0]
          $TagValues = $TagLine.split('==')[1]
        }
      elseif ($TagLine -like '*=/*')
        {
          $TagKeys = $TagLine.split('=/')[0]
          $TagValues = $TagLine.split('=/')[1]
        }

      $TagKeys = $TagKeys.split('||')
      $TagValues = $TagValues.split('||')

      $TagKey = if ($TagKeys.count -gt 1) { $TagKeys | ForEach-Object { "'$_'," } }else { $TagKeys }
      $TagKey = [string]$TagKey
      $TagKey = if ($TagKey -like "*',*") { $TagKey -replace '.$' }else { "'$TagKey'" }

      $TagValue = if ($TagValues.count -gt 1) { $TagValues | ForEach-Object { "'$_'," } }else { $TagValues }
      $TagValue = [string]$TagValue
      $TagValue = if ($TagValue -like "*',*") { $TagValue -replace '.$' }else { "'$TagValue'" }

      Write-Debug ('Running Resource Group Tag Inventory for: ' + $TagKey + ' : ' + $TagValue)

      if ($TagLine -like '*==*')
        {
          #Getting all the Resource Groups with the Tags, this will be used later
          $RGTagQuery = "$ContainerScopeQuery | mvexpand tags | extend tagKey = tostring(bag_keys(tags)[0]) | extend tagValue = tostring(tags[tagKey]) | where tagKey in~ ($TagKey) and tagValue in~ ($TagValue) | project id | order by id"
        }
      elseif ($TagLine -like '*=/*')
        {
          $RGTagQuery = "$ContainerScopeQuery | mvexpand tags | extend tagKey = tostring(bag_keys(tags)[0]) | extend tagValue = tostring(tags[tagKey]) | where tagKey in~ ($TagKey) and tagValue !in~ ($TagValue) | project id | order by id"
        }
      $TaggedResourceGroups = Get-AllAzGraphResource -query $RGTagQuery -subscriptionId $InScopeSub

      Write-Debug ('Running Resource Tag Inventory for: ' + $TagKey + ' : ' + $TagValue)
      if ($TagLine -like '*==*')
        {
          #Getting all the resources within the TAGs
          $ResourcesTagQuery = "$ResourceScopeQuery | mvexpand tags | extend tagKey = tostring(bag_keys(tags)[0]) | extend tagValue = tostring(tags[tagKey]) | where tagKey in~ ($TagKey) and tagValue in~ ($TagValue) | project id, name, subscriptionId, type, resourceGroup, location | order by id"
        }
      elseif ($TagLine -like '*=/*')
        {
          $ResourcesTagQuery = "$ResourceScopeQuery | mvexpand tags | extend tagKey = tostring(bag_keys(tags)[0]) | extend tagValue = tostring(tags[tagKey]) | where tagKey in~ ($TagKey) and tagValue !in~ ($TagValue) | project id, name, subscriptionId, type, resourceGroup, location | order by id"
        }
      $ResourcesWithTHETag = Get-AllAzGraphResource -query $ResourcesTagQuery -subscriptionId $InScopeSub

      if ($Counter -gt 0) {
        foreach ($resource in $AllTaggedResources) {
          if ($resource.id -notin $ResourcesWithTHETag.id) {
            $Script:TaggedResources += $AllTaggedResources | Where-Object { $_.id -ne $resource.id }
            $AllTaggedResources = $AllTaggedResources | Where-Object { $_.id -ne $resource.id }
          }
        }
        foreach ($RG in $AllTaggedResourceGroups) {
          if ($RG -notin $TaggedResourceGroups) {
            $AllTaggedResourceGroups = $AllTaggedResourceGroups | Where-Object { $_ -ne $RG }
          }
        }
      } else {
        $Counter ++
        $Script:TaggedResources += $ResourcesWithTHETag
        $AllTaggedResourceGroups += $TaggedResourceGroups
      }
    }
    #If Tags are present in the Resource Group level we make sure to get all the resources within that resource group
    if ($AllTaggedResourceGroups) {
      foreach ($ResourceGroup in $TaggedResourceGroups) {
        Write-Debug ('Double Checking Tagged Resources inside: ' + $ResourceGroup)
        $ResourcesTagQuery = "Resources | where id startswith '$ResourceGroup' | project id, name, subscriptionId, type, resourceGroup, location | order by id"

        $Script:TaggedResources += Get-AllAzGraphResource -query $ResourcesTagQuery -subscriptionId $InScopeSub
      }
    }
  }

  function Invoke-QueryExecution {
    param($type, $Subscription, $query, $checkId, $checkName, $selector, $validationAction)

    try {
      $ResourceType = $Script:AllResourceTypes | Where-Object { $_.Name -eq $type}
      if (![string]::IsNullOrEmpty($resourceType)) {
        # Execute the query and collect the results
        # $queryResults = Search-AzGraph -Query $query -First 1000 -Subscription $Subid -ErrorAction SilentlyContinue
        $queryResults = Get-AllAzGraphResource -query $query -subscriptionId $Subscription

        $queryResults = $queryResults | Select-Object -Property name, id, param1, param2, param3, param4, param5 -Unique

        foreach ($row in $queryResults) {
          $result = [PSCustomObject]@{
            validationAction = [string]$validationAction
            recommendationId = [string]$checkId
            name             = [string]$row.name
            Type             = [string]$type
            id               = [string]$row.id
            param1           = [string]$row.param1
            param2           = [string]$row.param2
            param3           = [string]$row.param3
            param4           = [string]$row.param4
            param5           = [string]$row.param5
            checkName        = [string]$checkName
            selector         = [string]$selector
          }
          $result
        }
      }

      if ($type -like '*azure-specialized-workloads/*') {
        $result = [PSCustomObject]@{
          validationAction = [string]$validationAction
          recommendationId = [string]$checkId
          name             = [string]''
          Type             = [string]$type
          id               = [string]''
          param1           = [string]''
          param2           = [string]''
          param3           = [string]''
          param4           = [string]''
          param5           = [string]''
          checkName        = [string]$checkName
          selector         = [string]$selector
        }
        $result
      }
    } catch {
      # Report Error
      $errorMessage = $_.Exception.Message
      Write-Host "Error processing query results: $errorMessage" -ForegroundColor Red
    }
  }

  function Start-ResourceExtraction {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
    param($Scope)

    if ($PSCmdlet.ShouldProcess('')) {
      $Scope = $Scope.split(" -")[0]

      if ($Scope.split("/").count -lt 5)
        {
          $Subid = $Scope.split("/")[2]
          $ResourceGroup = $null
        }
      elseif ($Scope.split("/").count -gt 4 -and $Scope.split("/").count -lt 8)
        {
          $Subid = $Scope.split("/")[2]
          $ResourceGroup = $Scope.split("/")[4]
        }
      elseif ($Scope.split("/").count -ge 9)
        {
          $Subid = $Scope.split("/")[2]
          $ResourceGroup = $Scope.split("/")[4]
        }

      # Set the variables used in the loop
      if ($Scope.split("/").count -lt 5)
        {
          # Extract and display resource types with the query with subscriptions, we need this to filter the subscriptions later
          $resultAllResourceTypes = $Script:PreInScopeResources | Where-Object { $_.id -like "/subscriptions/$Subid*"} | Group-Object -Property type -NoElement
          $Script:AllResourceTypes += $resultAllResourceTypes
        }
      elseif ($Scope.split("/").count -gt 4 -and $Scope.split("/").count -lt 8)
        {
          $resultAllResourceTypes = $Script:PreInScopeResources | Where-Object { $_.id -like "/subscriptions/$Subid/resourcegroups/$ResourceGroup*" } | Group-Object -Property type -NoElement
          $Script:AllResourceTypes += $resultAllResourceTypes
        }
      elseif ($Scope.split("/").count -ge 9)
        {
          $resultAllResourceTypes = $Script:PreInScopeResources | Where-Object { $_.id -eq $Scope } | Group-Object -Property type -NoElement
          $Script:AllResourceTypes += $resultAllResourceTypes
        }

        # Create the arrays used to store the kusto queries
        $kqlQueryMap = @{}
        $aprlKqlFiles = @()
        $ServiceNotAvailable = @()

        foreach ($Type in $resultAllResourceTypes.Name) {
          if ($Type.ToLower() -in $Script:SupportedResTypes) {
            $Type = $Type.replace('microsoft.', '')
            $Provider = $Type.split('/')[0]
            $ResourceType = $Type.split('/')[1]

            $Path = ''
            if ($Script:ShellPlatform -eq 'Win32NT') {
              $Path = ($clonePath + '\azure-resources\' + $Provider + '\' + $ResourceType)
              $RecommendationsPath = ($clonePath + '\azure-resources\' + $Provider + '\' + $ResourceType + '\recommendations.yaml')
              $RecommendationValidation = ''
              $RecommendationValidation = Get-ChildItem -Path $RecommendationsPath -File -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
              if (![string]::IsNullOrEmpty($RecommendationValidation))
                {
                  $aprlKqlFiles += Get-ChildItem -Path $Path -Filter '*.kql' -Recurse
                }
              else
                {
                  if (('microsoft.'+$Type) -notin $Script:AdvisorTypes)
                    {
                      $ServiceNotAvailable += ('microsoft.'+$Type)
                    }
                }
            } else {
              $Path = ($clonePath + '/azure-resources/')
              $ProvPath = ($Provider + '/' + $ResourceType)
              $RecommendationValidation = Get-ChildItem -Path $Path -Filter 'recommendations.yaml' -Recurse | Where-Object { $_.FullName -like "*$ProvPath*" }
              if (![string]::IsNullOrEmpty($RecommendationValidation))
                {
                  $aprlKqlFiles += Get-ChildItem -Path $Path -Filter '*.kql' -Recurse | Where-Object { $_.FullName -like "*$ProvPath*" }
                }
              else
                {
                  if (('microsoft.'+$Type) -notin $Script:AdvisorTypes)
                    {
                      $ServiceNotAvailable += ('microsoft.'+$Type)
                    }
                }
            }
          }
        }

        # Checks if specialized workloads will be validated
        if ($SAP.IsPresent) {
          if ($Script:ShellPlatform -eq 'Win32NT') {
            $aprlKqlFiles += Get-ChildItem -Path ($clonePath + '\azure-specialized-workloads\sap') -Filter '*.kql' -Recurse
          } else {
            $aprlKqlFiles += Get-ChildItem -Path ($clonePath + '/azure-specialized-workloads/sap') -Filter '*.kql' -Recurse
          }
        }

        if ($AVD.IsPresent) {
          if ($Script:ShellPlatform -eq 'Win32NT') {
            $aprlKqlFiles += Get-ChildItem -Path ($clonePath + '\azure-specialized-workloads\avd') -Filter '*.kql' -Recurse
          } else {
            $aprlKqlFiles += Get-ChildItem -Path ($clonePath + '/azure-specialized-workloads/avd') -Filter '*.kql' -Recurse
          }
        }

        if ($AVS.IsPresent) {
          if ($Script:ShellPlatform -eq 'Win32NT') {
            $aprlKqlFiles += Get-ChildItem -Path ($clonePath + '\azure-specialized-workloads\avs') -Filter '*.kql' -Recurse
          } else {
            $aprlKqlFiles += Get-ChildItem -Path ($clonePath + '/azure-specialized-workloads/avs') -Filter '*.kql' -Recurse
          }
        }

        if ($HPC.IsPresent) {
          if ($Script:ShellPlatform -eq 'Win32NT') {
            $aprlKqlFiles += Get-ChildItem -Path ($clonePath + '\azure-specialized-workloads\hpc') -Filter '*.kql' -Recurse
          } else {
            $aprlKqlFiles += Get-ChildItem -Path ($clonePath + '/azure-specialized-workloads/hpc') -Filter '*.kql' -Recurse
          }
        }

        # Populates the QueryMap hashtable
        foreach ($aprlKqlFile in $aprlKqlFiles) {
          if ($Script:ShellPlatform -eq 'Win32NT') {
            $kqlShort = [string]$aprlKqlFile.FullName.split('\')[-1]
          } else {
            $kqlShort = [string]$aprlKqlFile.FullName.split('/')[-1]
          }
          $kqlName = $kqlShort.split('.')[0]

          # Create APRL query map based on recommendation
          $kqlQueryMap[$kqlName] = $aprlKqlFile
        }

        if ($Script:RunbookQueryOverrides) {
          foreach ($queryOverridePath in $($Script:RunbookQueryOverrides)) {
            Write-Host "[Runbook]: Loading [$($queryOverridePath)] query overrides..." -ForegroundColor Cyan

            $overrideKqlFiles = Get-ChildItem -Path $queryOverridePath -Filter '*.kql' -Recurse

            foreach ($overrideKqlFile in $overrideKqlFiles) {
              if ($Script:ShellPlatform -eq 'Win32NT') {
                $kqlShort = [string]$overrideKqlFile.FullName.split('\')[-1]
              } else {
                $kqlShort = [string]$overrideKqlFile.FullName.split('/')[-1]
              }
              $kqlName = $kqlShort.split('.')[0]

              if ($kqlQueryMap.ContainsKey($kqlName)) {
                Write-Host "[Runbook]: Original [$kqlName] APRL query overridden by [$($overrideKqlFile.FullName)]." -ForegroundColor Cyan
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
          if ($Script:ShellPlatform -eq 'Win32NT') {
            $kqlshort = [string]$kqlFile.FullName.split('\')[-1]
          } else {
            $kqlshort = [string]$kqlFile.FullName.split('/')[-1]
          }

          $kqlname = $kqlshort.split('.')[0]

          # Read the query content from the file
          $baseQuery = Get-Content -Path $kqlFile.FullName | Out-String
          if ($Script:ShellPlatform -eq 'Win32NT') {
            $typeRaw = $kqlFile.DirectoryName.split('\')
          } else {
            $typeRaw = $kqlFile.DirectoryName.split('/')
          }
          $kqltype = ('microsoft.' + $typeRaw[-3] + '/' + $typeRaw[-2])

          $checkId = $kqlname.Split('/')[-1].ToLower()

          if ($Script:RunbookChecks -and $Script:RunbookChecks.Count -gt 0) {
            # A runbook has been provided...

            if ($Script:RunbookChecks.ContainsKey($checkId)) {
              # A check has been configured in the runbook for this query...

              $runbookCheckCt = 0

              $check = $Script:RunbookChecks[$checkId]

              $check.PSObject.Properties | ForEach-Object {
                $checkName = $_.Name
                $selectorName = $_.Value

                if ($Script:RunbookSelectors.ContainsKey($selectorName)) {
                  # If a matching selector exists, add a new query to the queries array
                  # that includes the appropriate selector...

                  $checkSelector = $Script:RunbookSelectors[$selectorName]

                  # First, resolve any // selectors in the query...

                  $selectorQuery = $baseQuery.Replace('// selector', "| where $checkSelector")

                  # Resolve named selectors...
                  foreach ($selectorKey in $Script:RunbookSelectors.Keys) {
                    $namedSelector = $Script:RunbookSelectors[$selectorKey]
                    $selectorQuery = $selectorQuery.Replace("// selector:$selectorName", "| where $namedSelector")
                  }

                  if ($UseImplicitRunbookSelectors) {
                    # Then, wrap the entire query in an inner join to apply a global selector.
                    # With this approach, queries that implement the APRL interface
                    # (projecting the recId, id, tags, etc.) columns can be refined using
                    # selectors without any changes to the original query. The original query
                    # is wrapped in an inner join that limits the results to only those that
                    # match the selector.

                    $selectorQuery = 'resources ' `
                      + " | where $checkSelector " `
                      + ' | project id ' `
                      + ' | join kind=inner ( ' `
                      + " $selectorQuery ) on id " `
                      + ' | project-away id1'
                  }

                  # Merge parameters after selectors have been applied (selectors may include parameters)...
                  foreach ($parameterName in $Script:RunbookParameters.Keys) {
                    $value = $Script:RunbookParameters[$parameterName]
                    $selectorQuery = $selectorQuery.Replace("{{$parameterName}}", $value)
                  }

                  $queries += [PSCustomObject]@{
                    checkId   = [string]$checkId
                    checkName = [string]$checkName
                    selector  = [string]$selectorName
                    query     = [string]$selectorQuery
                    type      = [string]$kqltype
                  }

                  $runbookCheckCt++

                } else {
                  Write-Host "[Runbook]: Selector $selectorName not found in runbook. Skipping check..." -ForegroundColor Yellow
                }
              }

              if ($queries.Count -gt 0) {
                Write-Host "[Runbook]: There are $runbookCheckCt runbook check(s) configured for $checkId. Running checks..." -ForegroundColor Cyan
              }
            }
          } else {
            # A runbook hasn't been configured. The queries array will contain
            # just one element -- the original query. No selectors.

            $queries += [PSCustomObject]@{
              checkId   = [string]$checkId
              checkName = [string]$null
              selector  = 'APRL'
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

          Write-Host '++++++++++++++++++ ' -NoNewline
          if ($selector -eq 'APRL') {
            Write-Host "[APRL]: Microsoft.$type - $checkId" -ForegroundColor Green -NoNewline
          } else {
            Write-Host "[Runbook]: [$checkName (selector: '$selector')]: $checkId" -ForegroundColor Green -NoNewline
          }
          Write-Host ' +++++++++++++++'

          # Validating if Query is Under Development
          if ($query -match 'development') {
            Write-Host "Query $checkId under development - Validate Recommendation manually" -ForegroundColor Yellow
            $query = "resources | where type =~ '$type' | project name,id"
            $Script:results += Invoke-QueryExecution -type $type -Subscription $Subid -query $query -checkId $checkId -checkName $checkName -selector $selector -validationAction 'IMPORTANT - Query under development - Validate Resources manually'
          } elseif ($query -match 'cannot-be-validated-with-arg') {
            Write-Host "IMPORTANT - Recommendation $checkId cannot be validated with ARGs - Validate Resources manually" -ForegroundColor Yellow
            $query = "resources | where type =~ '$type' | project name,id"
            $Script:results += Invoke-QueryExecution -type $type -Subscription $Subid -query $query -checkId $checkId -checkName $checkName -selector $selector -validationAction 'IMPORTANT - Recommendation cannot be validated with ARGs - Validate Resources manually'
          } else {
            $Script:results += Invoke-QueryExecution -type $type -Subscription $Subid -query $query -checkId $checkId -checkName $checkName -selector $selector -validationAction 'APRL - Queries'
          }
        }

        # Unless we're using a runbook...
        if (!($Script:RunbookChecks -and $Script:RunbookChecks.Count -gt 0)) {
          # Store all resourcetypes not in APRL
          foreach ($type in $ServiceNotAvailable) {
            Write-Host "Type $type Not Available In APRL - Validate Service manually" -ForegroundColor Yellow
            $query = "resources | where type =~ '$type' | project name,id"
            $Script:results += Invoke-QueryExecution -type $type -Subscription $Subid -query $query -checkId $type -selector 'APRL' -checkName '' -validationAction 'IMPORTANT - Resource Type is not available in either APRL or Advisor - Validate Resources manually if Applicable, if not Delete this line'
          }
        }
      }
    }

  function Invoke-ResourceFiltering {
    if ($Tags) {
      $Script:InScope += foreach ($Resource in $Script:PreInScopeResources)
        {
          if ($Resource.id -in $Script:TaggedResources.id)
            {
              $Resource
            }
        }
      }
    else
        {
          $Script:InScope = $Script:PreInScopeResources
      }

    if (![string]::IsNullOrEmpty($Script:ExcludeList))
      {
        $Script:InScope = $Script:InScope | Where-Object {$_.id -notin $Script:ExcludeList.id}
      }

    $Script:ImpactedResources += foreach ($Temp in $Script:results)
      {
        if ($Temp.id -in $Script:InScope.id)
          {
              $TempDetails = ($Script:PreInScopeResources | Where-Object { $_.id -eq $Temp.id } | Select-Object -First 1)
              $result = [PSCustomObject]@{
                validationAction = $Temp.validationAction
                recommendationId = $Temp.recommendationId
                name             = $Temp.name
                id               = $Temp.id
                type             = $TempDetails.type
                location         = $TempDetails.location
                subscriptionId   = $TempDetails.subscriptionId
                resourceGroup    = $TempDetails.resourceGroup
                param1           = $Temp.param1
                param2           = $Temp.param2
                param3           = $Temp.param3
                param4           = $Temp.param4
                param5           = $Temp.param5
                checkName        = $Temp.checkName
                selector         = $Temp.selector
              }
            $result
      } else {
        $TempDetails = ($Script:AllResources | Where-Object { $_.id -eq $Temp.id } | Select-Object -First 1)
        $result = [PSCustomObject]@{
          validationAction = $Temp.validationAction
          recommendationId = $Temp.recommendationId
          name             = $Temp.name
          id               = $Temp.id
          location         = $TempDetails.location
          subscriptionId   = $TempDetails.subscriptionId
          resourceGroup    = $TempDetails.resourceGroup
          param1           = $Temp.param1
          param2           = $Temp.param2
          param3           = $Temp.param3
          param4           = $Temp.param4
          param5           = $Temp.param5
          checkName        = $Temp.checkName
          selector         = $Temp.selector
          tagged           = $false
        }
        $result
      }
    }

    $Script:OutOfScope += foreach ($ResIID in $Script:PreOutOfScopeResources)
      {
        if ($ResIID.type -notin $Script:SupportedResTypes)
          {
            $result = [PSCustomObject]@{
              description      = 'No Action Required - This ResourceType is out of scope of Well-Architected Reliability Assessment engagements.'
              type             = $ResIID.type
              subscriptionId   = $ResIID.subscriptionId
              resourceGroup    = $ResIID.resourceGroup
              name             = $ResIID.name
              location         = $ResIID.location
              id               = $ResIID.id
            }
          $result
          }
      }
    }

  function Resolve-ResourceType {
    $TempTypes = $Script:ImpactedResources | Where-Object { $_.validationAction -eq 'IMPORTANT - Resource Type is not available in either APRL or Advisor - Validate Resources manually if Applicable, if not Delete this line' }
    $Script:AllResourceTypes = $Script:AllResourceTypes | Sort-Object -Property Count -Descending
    $Looper = $Script:AllResourceTypes | Select-Object -Property Name -Unique
    foreach ($result in $Looper.Name) {
      $ResourceTypeCount = (($Script:AllResourceTypes | Where-Object { $_.Name -eq $result }) | Select-Object -ExpandProperty Count | Measure-Object -Sum).Sum
      $ResultType = $result
      if ($ResultType -in $TempTypes.recommendationId) {
        $tmp = [PSCustomObject]@{
          'Resource Type'               = [string]$ResultType
          'Number of Resources'         = [string]$ResourceTypeCount
          'Available in APRL/ADVISOR?'  = 'No'
          'Assessment Owner'            = ''
          'Status'                      = ''
          'Notes'                       = ''
        }
        $Script:AllResourceTypesOrdered += $tmp
      } elseif ($ResultType -notin $TempTypes.recommendationId) {
        $tmp = [PSCustomObject]@{
          'Resource Type'               = [string]$ResultType
          'Number of Resources'         = [string]$ResourceTypeCount
          'Available in APRL/ADVISOR?'  = 'Yes'
          'Assessment Owner'            = ''
          'Status'                      = ''
          'Notes'                       = ''
        }
        $Script:AllResourceTypesOrdered += $tmp
      }
    }
  }

  function Invoke-AdvisoryExtraction {
    Param($Subid,$ResourceGroup)
    if (![string]::IsNullOrEmpty($ResourceGroup)) {
        $advquery = "advisorresources | where type == 'microsoft.advisor/recommendations' and tostring(properties.category) in ('HighAvailability','Performance','OperationalExcellence') | where resourceGroup =~ '$ResourceGroup' | order by id"
        $queryResults = Get-AllAzGraphResource -Query $advquery -subscriptionId $Subid
      } else {
        $advquery = "advisorresources | where type == 'microsoft.advisor/recommendations' and tostring(properties.category) in ('HighAvailability','Performance','OperationalExcellence') | order by id"
        $queryResults = Get-AllAzGraphResource -Query $advquery -subscriptionId $Subid
      }

      $Script:AllAdvisories += foreach ($row in $queryResults) {
        if (![string]::IsNullOrEmpty($row.properties.resourceMetadata.resourceId)) {
          $TempResource = ''
          $TempResource = ($Script:PreInScopeResources | Where-Object { $_.id -eq $row.properties.resourceMetadata.resourceId } | Select-Object -First 1)
          $result = [PSCustomObject]@{
            recommendationId = [string]$row.properties.recommendationTypeId
            type             = [string]$row.Properties.impactedField
            name             = [string]$row.properties.impactedValue
            id               = [string]$row.properties.resourceMetadata.resourceId
            subscriptionId   = [string]$TempResource.subscriptionId
            resourceGroup    = [string]$TempResource.resourceGroup
            location         = [string]$TempResource.location
            category         = [string]$row.properties.category
            impact           = [string]$row.properties.impact
            description      = [string]$row.properties.shortDescription.solution
          }
          $result
        }
      }
    }

  function Resolve-SupportTicket {
    $Tickets = $Script:SupportTickets
    $Script:SupportTickets = @()
    $Script:SupportTickets += foreach ($Ticket in $Tickets) {
      $tmp = @{
        'Ticket ID'         = [string]$Ticket.properties.supportTicketId;
        'Severity'          = [string]$Ticket.properties.severity;
        'Status'            = [string]$Ticket.properties.status;
        'Support Plan Type' = [string]$Ticket.properties.supportPlanType;
        'Creation Date'     = [string]$Ticket.properties.createdDate;
        'Modified Date'     = [string]$Ticket.properties.modifiedDate;
        'Title'             = [string]$Ticket.properties.title;
        'Related Resource'  = [string]$Ticket.properties.technicalTicketDetails.resourceId
      }
      $tmp
    }
  }

  function Invoke-RetirementExtraction {
    param($Subid)

    $retquery = "servicehealthresources | where properties.EventSubType contains 'Retirement' | order by id"
    $queryResults = Get-AllAzGraphResource -Query $retquery -subscriptionId $Subid

    $Script:AllRetirements += foreach ($row in $queryResults) {
      $OutagesRetired = $Script:RetiredOutages | Where-Object { $_.name -eq $row.properties.TrackingId }

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
      $result
    }
  }

  function Invoke-ServiceHealthExtraction {
    param($Subid)

    $Servicequery = "resources | where type == 'microsoft.insights/activitylogalerts' | order by id"
    $queryResults = Get-AllAzGraphResource -Query $Servicequery -subscriptionId $Subid

    $Rowler = @()
    $Rowler += foreach ($row in $queryResults) {
      foreach ($type in $row.properties.condition.allOf) {
        if ($type.equals -eq 'ServiceHealth') {
          $row
        }
      }
    }

    $Script:AllServiceHealth += foreach ($Row in $Rowler) {
      $SubName = ($SubIds | Where-Object { $_.Id -eq ($Row.properties.scopes.split('/')[2]) }).Name
      $EventType = if ($Row.Properties.condition.allOf.anyOf | Select-Object -Property equals) { $Row.Properties.condition.allOf.anyOf | Select-Object -Property equals | ForEach-Object { switch ($_.equals) { 'Incident' { 'Service Issues' } 'Informational' { 'Health Advisories' } 'ActionRequired' { 'Security Advisory' } 'Maintenance' { 'Planned Maintenance' } } } } Else { 'All' }
      $Services = if ($Row.Properties.condition.allOf | Where-Object { $_.field -eq 'properties.impactedServices[*].ServiceName' }) { $Row.Properties.condition.allOf | Where-Object { $_.field -eq 'properties.impactedServices[*].ServiceName' } | Select-Object -Property containsAny | ForEach-Object { $_.containsAny } } Else { 'All' }
      $Regions = if ($Row.Properties.condition.allOf | Where-Object { $_.field -eq 'properties.impactedServices[*].ImpactedRegions[*].RegionName' }) { $Row.Properties.condition.allOf | Where-Object { $_.field -eq 'properties.impactedServices[*].ImpactedRegions[*].RegionName' } | Select-Object -Property containsAny | ForEach-Object { $_.containsAny } } Else { 'All' }
      $ActionGroupName = if ($Row.Properties.actions.actionGroups.actionGroupId) { $Row.Properties.actions.actionGroups.actionGroupId.split('/')[8] } else { '' }

      $result = [PSCustomObject]@{
        Name         = [string]$row.name
        Subscription = [string]$SubName
        Enabled      = [string]$Row.properties.enabled
        EventType    = $EventType
        Services     = $Services
        Regions      = $Regions
        ActionGroup  = $ActionGroupName
      }
      $result
    }
  }

  function New-JsonFile {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
    param()

    if ($PSCmdlet.ShouldProcess('')) {
      <#  if($ResourceGroupFile){

        $ResourceExporter = @{
          Resource = $(Get-ResourceGroupsByList -ObjectList $Script:results -FilterList $resourcegrouplist -KeyColumn "id")
        }
      else{
        $ResourceExporter = @{
          Resource = $Script:results
        }
      } #>

      #Ternary Expression If ResourceGroupFile is present, then get the ResourceGroups by List, else get the results
      $ResourceExporter = @{
        ImpactedResources = $ResourceGroupList ? $(Get-ResourceGroupsByList -ObjectList $Script:ImpactedResources -FilterList $resourcegrouplist -KeyColumn "id") : $Script:ImpactedResources
      }
      $OutOfScopeExporter = @{
        OutOfScope = $Script:OutOfScope
      }

      $ResourceTypeExporter = @{
        ResourceType = $Script:AllResourceTypesOrdered
      }
      $AdvisoryExporter = @{
        Advisory = $Script:AllAdvisories
      }
      $OutageExporter = @{
        Outages = $Script:Outageslist
      }
      $RetirementExporter = @{
        Retirements = $Script:AllRetirements
      }
      $SupportExporter = @{
        SupportTickets = $Script:SupportTickets
      }
      $ServiceHealthExporter = @{
        ServiceHealth = $Script:AllServiceHealth
      }
      $ScriptDetailsExporter = @{
        ScriptDetails = $Script:ScriptData
      }
      if ($Debugging.IsPresent)
        {
          $InScopeExporter = @{
            InScopeResources = $Script:InScope
          }
          $PreInScopeExporter = @{
            InScopeBeforeTagFiltering = $Script:PreInScopeResources
          }
          $TaggedResourceExporter = @{
            TaggedResourcesFilter = $Script:TaggedResources
          }
          $ImpactedResourcesBeforeFilteringExporter = @{
            ImpactedResourcesBeforeFiltering = $Script:results
          }
        }


      $ExporterArray = @()
      $ExporterArray += $ResourceExporter
      $ExporterArray += $ResourceTypeExporter
      $ExporterArray += $AdvisoryExporter
      $ExporterArray += $OutageExporter
      $ExporterArray += $RetirementExporter
      $ExporterArray += $SupportExporter
      $ExporterArray += $ServiceHealthExporter
      $ExporterArray += $ScriptDetailsExporter
      $ExporterArray += $OutOfScopeExporter
      if ($Debugging.IsPresent)
        {
          $ExporterArray += $InScopeExporter
          $ExporterArray += $PreInScopeExporter
          $ExporterArray += $TaggedResourceExporter
          $ExporterArray += $ImpactedResourcesBeforeFilteringExporter
        }

      $Script:JsonFile = ($PSScriptRoot + '\WARA-File-' + (Get-Date -Format 'yyyy-MM-dd-HH-mm') + '.json')

      $ExporterArray | ConvertTo-Json -Depth 15 | Out-File $Script:JsonFile
    }
  }


  #Call the functions
  $Script:Version = '2.0.13'
  Write-Host 'Version: ' -NoNewline
  Write-Host $Script:Version -ForegroundColor DarkBlue

  if ($Help.IsPresent) {
    Get-HelpMessage
    Exit
  }

  if ($ConfigFile) {
    $Scopes = @()
    $ConfigData = Import-ConfigFileData -file $ConfigFile
    $TenantID = $ConfigData.TenantID | Select-Object -First 1
    $Scopes += $ConfigData.subscriptions
    $Scopes += $ConfigData.resourcegroups
    $Scopes += $ConfigData.resources
    $locations = $ConfigData.locations
    $RunbookFile = $ConfigData.RunbookFile
    $Tags = $ConfigData.Tags
  }
  else {
    $Scopes = @()
    if ($ResourceGroups)
      {
        $Scopes += foreach ($RG in $ResourceGroups)
          {
            $RG
          }
      }
    else
      {
        $Scopes += foreach ($Sub in $SubscriptionIds)
          {
            $Sub
          }
      }
  }

  Write-Debug "Checking Parameters"
  Test-SubscriptionParameter

  Write-Debug 'Reseting Variables'
  Invoke-ResetVariable

  Write-Debug 'Calling Function: Test-Requirements'
  Test-Requirement

  Write-Debug 'Calling Function: Set-LocalFiles'
  Set-LocalFile

  Write-Debug 'Calling Function: Test-Runbook'
  Test-Runbook

  Write-Debug "Calling Function: Connect-ToAzure"
  Connect-ToAzure

  #Write-Debug "Calling Function: Invoke-PSModules"
  #Invoke-PSModules

  Write-Debug 'Calling Function: Start-ScopesLoop'
  Start-ScopesLoop

  Write-Debug 'Calling Function: Invoke-ResourcesFiltering'
  Invoke-ResourceFiltering

  Write-Debug 'Calling Function: Resolve-ResourceTypes'
  Resolve-ResourceType

  Write-Debug 'Calling Function: Resolve-SupportTickets'
  Resolve-SupportTicket

  Write-Debug 'Calling Function: New-JsonFile'
  New-JsonFile

}

$TotalTime = $Script:Runtime.Totalminutes.ToString('#######.##')

Write-Host '---------------------------------------------------------------------'
Write-Host ('Execution Complete. Total Runtime was: ') -NoNewline
Write-Host $TotalTime -NoNewline -ForegroundColor Cyan
Write-Host (' Minutes')
Write-Host 'Result File: ' -NoNewline
Write-Host $Script:JsonFile -ForegroundColor Blue
Write-Host '---------------------------------------------------------------------'
