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
  [switch]$GUI,
  [switch]$ResourceGroupGUI,
  [switch]$UseImplicitRunbookSelectors,
  $RunbookFile,
  $SubscriptionIds,
  $ResourceGroups,
  $TenantID,
  [ValidateSet('AzureCloud', 'AzureUSGovernment')]
  $AzureEnvironment = 'AzureCloud',
  $ConfigFile
  )

#import-module "./modules/collector.psm1" -Force

if ($Debugging.IsPresent) { $DebugPreference = 'Continue' } else { $DebugPreference = 'silentlycontinue' }



$Script:ShellPlatform = $PSVersionTable.Platform

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

  function New-AzTenantSelection {
    return Get-AzTenant | Out-ConsoleGridView -OutputMode Single -Title "Select Tenant"
  }

  function New-AzSubscriptionSelection {
    param (
      [Parameter(Mandatory=$true)]
      [string]$TenantId
    )
    return Get-AzSubscription -TenantId $TenantId | Out-ConsoleGridView -OutputMode Multiple -title "Select Subscription(s)"
  }

  function New-AzResourceGroupSelection {
    param (
      [Parameter(Mandatory=$false)]
      [string[]]$SubscriptionIds
    )
    $result = $SubscriptionIds ? (Get-AllResourceGroup -SubscriptionId $SubscriptionIds) : (Get-AllResourceGroup)
    return $result | Select-Object ResourceGroup, SubscriptionName, resourceId | Out-ConsoleGridView -OutputMode Multiple -Title "Select Resource Group(s)"
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
      [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
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
    if ([string]::IsNullOrEmpty($SubscriptionIds) -and [string]::IsNullOrEmpty($ConfigFile) -and -not $GUI)
      {
        Write-Host ""
        Write-Host "Suscription ID or Subscription File is required"
        Write-Host ""
        Exit
      }
  }

  function Get-HelpMessage {
    Write-Host ''
    Write-Host 'Parameters'
    Write-Host ''
    Write-Host ' -TenantID <ID>        :  Optional; tenant to be used. '
    Write-Host ' -SubscriptionIds <IDs>:  Optional (or SubscriptionsFile); Specifies Subscription(s) to be included in the analysis: Subscription1,Subscription2. '
    Write-Host ' -SubscriptionsFile    :  Optional (or SubscriptionIds); specifies the file with the subscription list to be analysed (one subscription per line). '
    Write-Host ' -RunbookFile          :  Optional; specifies the file with the runbook (selectors & checks) to be used. '
    Write-Host ' -ResourceGroups       :  Optional; specifies Resource Group(s) to be included in the analysis: "ResourceGroup1","ResourceGroup2." '
    Write-Host ' -Debug                :  Writes Debugging information of the script during the execution. '
    Write-Host ''
    Write-Host 'Examples: '
    Write-Host '  Run against all the subscriptions in the Tenant'
    Write-Host '  .\1_wara_collector.ps1 -TenantID XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX'
    Write-Host ''
    Write-Host '  Run against specific Subscriptions in the Tenant'
    Write-Host '  .\1_wara_collector.ps1 -TenantID XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX -SubscriptionIds YYYYYYYY-YYYY-YYYY-YYYY-YYYYYYYYYYYY,AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA'
    Write-Host ''
    Write-Host '  Run against the subscriptions in a file the Tenant'
    Write-Host '  .\1_wara_collector.ps1 -TenantID XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX -SubscriptionsFile "C:\Temp\Subscriptions.txt"'
    Write-Host ''
    Write-Host ''
  }

  function Invoke-ResetVariable {
    $Script:SubIds = ''
    $Script:AllResourceTypes = @()
    $Script:GluedTypes = @()
    $Script:AllResourceTypesOrdered = @()
    $Script:AllAdvisories = @()
    $Script:AllRetirements = @()
    $Script:AllServiceHealth = @()
    $Script:results = @()
    $Script:AllResources = @()
    $Script:Resources = @()
    $Script:TaggedResources = @()


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
             Write-Host "Validating " -NoNewline
        Write-Host "Microsoft.PowerShell.ConsoleGuiTools" -ForegroundColor Cyan -NoNewline
        Write-Host " Module.."
        $ConsoleGUITools = Get-Module -Name Microsoft.PowerShell.ConsoleGuiTools -ListAvailable -ErrorAction silentlycontinue
        if ($null -eq $ConsoleGUITools)
          {
            Write-Host "Installing ConsoleGuiTools Modules" -ForegroundColor Yellow
            Install-Module -Name Microsoft.PowerShell.ConsoleGuiTools -SkipPublisherCheck -InformationAction SilentlyContinue
          }
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
            Version       = $Script:Version
            SAP           = if($SAP.IsPresent){$true}else{$false}
            AVD           = if($AVD.IsPresent){$true}else{$false}
            AVS           = if($AVS.IsPresent){$true}else{$false}
            HPC           = if($HPC.IsPresent){$true}else{$false}
            TAGFiltering  = if($TagsFile -or $Tags){$true}else{$false}
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
          $RootTypes = Get-ChildItem -Path "$clonePath\azure-resources\" -Directory
        } else {
          $RootTypes = Get-ChildItem -Path "$clonePath/azure-resources/" -Directory
        }
        $Script:GluedTypes += foreach ($RootType in $RootTypes) {
          $RootName = $RootType.Name
          $SubTypes = Get-ChildItem -Path $RootType -Directory
          foreach ($SubDir in $SubTypes) {
            $SubDirName = $SubDir.Name
            if (Get-ChildItem -Path $SubDir.FullName -File 'recommendations.yaml') {
              $GlueType = ('Microsoft.' + $RootName + '/' + $SubDirName)
              $GlueType.ToLower()
            }
          }
        }
      } catch {
        # Report Error
        $errorMessage = $_.Exception.Message
        Write-Host "Error executing function LocalFiles: $errorMessage" -ForegroundColor Red
      }
    }
  }

  function Connect-ToAzure {
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
          Connect-AzAccount -Tenant $TenantID -WarningAction SilentlyContinue -Environment $AzureEnvironment
        }
      } else {
        Connect-AzAccount -Tenant $TenantID -WarningAction SilentlyContinue -Environment $AzureEnvironment
      }
      #Set the default variable with the list of subscriptions in case no Subscription File was informed
      $Script:SubIds = Get-AzSubscription -TenantId $TenantID -WarningAction SilentlyContinue
    } else {
      Connect-AzAccount -Identity -Environment $AzureEnvironment
      $Script:SubIds = Get-AzSubscription -WarningAction SilentlyContinue
    }



    # Getting Outages
    Write-Debug 'Exporting Outages'
    $Date = (Get-Date).AddMonths(-24)
    $DateOutages = (Get-Date).AddMonths(-3)
    $DateCore = (Get-Date).AddMonths(-3)
    $Date = $Date.ToString('MM/dd/yyyy')
    $Outages = @()
    $SupTickets = @()
    if ($AzureEnvironment -eq 'AzureUSGovernment') {
      $BaseURL = 'management.usgovcloudapi.net'
    } else {
      $BaseURL = 'management.azure.com'
    }
    foreach ($sub in $SubscriptionIds) {
      Select-AzSubscription -Subscription $sub -WarningAction SilentlyContinue -InformationAction SilentlyContinue | Out-Null

      $Token = Get-AzAccessToken

      $header = @{
        'Authorization' = 'Bearer ' + $Token.Token
      }

      try {
        $url = ('https://' + $BaseURL + '/subscriptions/' + $Sub + '/providers/Microsoft.ResourceHealth/events?api-version=2022-10-01&queryStartTime=' + $Date)
        $Outages += Invoke-RestMethod -Uri $url -Headers $header -Method GET
      } catch { $null }

      try {
        $supurl = ('https://' + $BaseURL + '/subscriptions/' + $sub + '/providers/Microsoft.Support/supportTickets?api-version=2020-04-01')
        $SupTickets += Invoke-RestMethod -Uri $supurl -Headers $header -Method GET
      } catch { $null }
    }

    $Script:Outageslist = $Outages.value | Where-Object { $_.properties.impactStartTime -gt $DateOutages } | Sort-Object @{Expression = 'properties.eventlevel'; Descending = $false }, @{Expression = 'properties.status'; Descending = $false } | Select-Object -Property name, properties -First 15
    $Script:RetiredOutages = $Outages.value | Sort-Object @{Expression = 'properties.eventlevel'; Descending = $false }, @{Expression = 'properties.status'; Descending = $false } | Select-Object -Property name, properties
    $Script:SupportTickets = $SupTickets.value | Where-Object { $_.properties.severity -ne 'Minimal' -and $_.properties.createdDate -gt $DateCore } | Select-Object -Property name, properties
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

  function Test-SubscriptionFile {
    # Checks if the Subscription file  and TenantID were informed
    if (![string]::IsNullOrEmpty($SubscriptionsFile)) {
      #$filePath = Read-Host "Please provide the path to a text file containing subscription IDs (one SubId per line)"

      # Check if the file exists
      if (Test-Path $SubscriptionsFile -PathType Leaf) {
        # Read the content of the file and split it into an array of subscription IDs
        $Script:SubIds = Get-Content $SubscriptionsFile -ErrorAction Stop | ForEach-Object { $_ -split ',' }

        # Display the subscription IDs
        Write-Host '---------------------------------------------------------------------'
        Write-Host 'Executing Analysis from Subscription File: ' -NoNewline
        Write-Host $SubscriptionsFile -ForegroundColor Blue
        Write-Host '---------------------------------------------------------------------'
        Write-Host 'The following Subscription IDs were found: '
        Write-Host $SubIds
      } else {
        Write-Host "File not found: $SubscriptionsFile"
      }
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

  function Start-ResourceExtraction {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
    param()

    if ($PSCmdlet.ShouldProcess('')) {
      function Invoke-QueryExecution {
        param($type, $query, $checkId, $checkName, $selector, $validationAction)

        try {
          $ResourceType = $Script:AllResourceTypes | Where-Object { $_.Name -eq $type }
          if (![string]::IsNullOrEmpty($resourceType)) {
            # Execute the query and collect the results
            # $queryResults = Search-AzGraph -Query $query -First 1000 -Subscription $Subid -ErrorAction SilentlyContinue
            $queryResults = Get-AllAzGraphResource -query $query -subscriptionId $Subid

            $queryResults = $queryResults | Select-Object -Property name, id, param1, param2, param3, param4, param5 -Unique

            foreach ($row in $queryResults) {
              $result = [PSCustomObject]@{
                validationAction = [string]$validationAction
                recommendationId = [string]$checkId
                name             = [string]$row.name
                id               = [string]$row.id
                param1           = [string]$row.param1
                param2           = [string]$row.param2
                param3           = [string]$row.param3
                param4           = [string]$row.param4
                param5           = [string]$row.param5
                checkName        = [string]$checkName
                selector         = [string]$selector
              }
              $Script:results += $result
            }
          }

          if ($type -like '*azure-specialized-workloads/*') {
            $result = [PSCustomObject]@{
              validationAction = [string]$validationAction
              recommendationId = [string]$checkId
              name             = [string]''
              id               = [string]''
              param1           = [string]''
              param2           = [string]''
              param3           = [string]''
              param4           = [string]''
              param5           = [string]''
              checkName        = [string]$checkName
              selector         = [string]$selector
            }
            $Script:results += $result
          }
        } catch {
          # Report Error
          $errorMessage = $_.Exception.Message
          Write-Host "Error processing query results: $errorMessage" -ForegroundColor Red
        }
      }

      function Invoke-TagFiltering {
        param($Subid)

        if ($TagsFile) {
          $TagFile = Get-Item -Path $TagsFile
          $TagFile = $TagFile.FullName
          $TagFilter = Get-Content -Path $TagFile
        }
        if ($Tags) {
          $TagFilter = $Tags
        }
        $Counter = 0

        # Each line in the Tag Filtering file will be processed
        $AllTaggedResourceGroups = @()
        Foreach ($TagLine in $TagFilter) {
          # Finding the TagKey and all the TagValues in the line
          $TagKeys = $TagLine.split(':')[0]
          $TagValues = $TagLine.split(':')[1]

          $TagKeys = $TagKeys.split(',')
          $TagValues = $TagValues.split(',')

          $TagKey = if ($TagKeys.count -gt 1) { $TagKeys | ForEach-Object { "'$_'," } }else { $TagKeys }
          $TagKey = [string]$TagKey
          $TagKey = if ($TagKey -like "*',*") { $TagKey -replace '.$' }else { "'$TagKey'" }

          $TagValue = if ($TagValues.count -gt 1) { $TagValues | ForEach-Object { "'$_'," } }else { $TagValues }
          $TagValue = [string]$TagValue
          $TagValue = if ($TagValue -like "*',*") { $TagValue -replace '.$' }else { "'$TagValue'" }

          Write-Debug ('Running Resource Group Tag Inventory for: ' + $TagKey + ' : ' + $TagValue)

          #Getting all the Resource Groups with the Tags, this will be used later
          $RGTagQuery = "ResourceContainers | where type =~ 'microsoft.resources/subscriptions/resourcegroups' | mvexpand tags | extend tagKey = tostring(bag_keys(tags)[0]) | extend tagValue = tostring(tags[tagKey]) | where tagKey in ($TagKey) and tagValue in ($TagValue) | project id | order by id"

          $TaggedResourceGroups = Get-AllAzGraphResource -query $RGTagQuery -subscriptionId $Subid

          Write-Debug ('Running Resource Tag Inventory for: ' + $TagKey + ' : ' + $TagValue)
          #Getting all the resources within the TAGs
          $ResourcesTagQuery = "Resources | mvexpand tags | extend tagKey = tostring(bag_keys(tags)[0]) | extend tagValue = tostring(tags[tagKey]) | where tagKey in ($TagKey) and tagValue in ($TagValue) | project id, name, subscriptionId, resourceGroup, location | order by id"

          $ResourcesWithTHETag = Get-AllAzGraphResource -query $ResourcesTagQuery -subscriptionId $Subid

          if ($Counter -gt 0) {
            foreach ($resource in $Script:TaggedResources) {
              if ($resource.id -notin $ResourcesWithTHETag.id) {
                $Script:TaggedResources = $Script:TaggedResources | Where-Object { $_.id -ne $resource.id }
              }
            }
            foreach ($RG in $AllTaggedResourceGroups) {
              if ($RG -notin $TaggedResourceGroups) {
                $AllTaggedResourceGroups = $AllTaggedResourceGroups | Where-Object { $_ -ne $RG }
              }
            }
          } else {
            $Counter ++
            $Script:TaggedResources = $ResourcesWithTHETag
            $AllTaggedResourceGroups += $TaggedResourceGroups
          }
        }
        #If Tags are present in the Resource Group level we make sure to get all the resources within that resource group
        if ($AllTaggedResourceGroups) {
          foreach ($ResourceGroup in $TaggedResourceGroups) {
            Write-Debug ('Double Checking Tagged Resources inside the Resource Group: ' + $ResourceGroup)
            $ResourcesTagQuery = "Resources | where id startswith '$ResourceGroup' | project id, name, subscriptionId, resourceGroup, location | order by id"

            $Script:TaggedResources += Get-AllAzGraphResource -query $ResourcesTagQuery -subscriptionId $Subid
          }
        }
      }

      function Invoke-AllResourceExtraction {
        param($subid)

        $Script:AllResources += Get-AllAzGraphResource -subscriptionId $Subid
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
        } else {
          # If using the variable set during the login to Azure, Subscription Name is available
          $SubName = $Subid.Name
          $Subid = $Subid.id
        }
        Write-Host '---------------------------------------------------------------------'
        Write-Host 'Validating Subscription: ' -NoNewline
        Write-Host $SubName -ForegroundColor Cyan

        Set-AzContext -Subscription $Subid -ErrorAction SilentlyContinue -WarningAction SilentlyContinue | Out-Null

        Write-Host '----------------------------'
        Write-Host 'Collecting: ' -NoNewline
        Write-Host 'Resources Details' -ForegroundColor Magenta
        Invoke-AllResourceExtraction $Subid

        if ($TagsFile -or $Tags) {
          Write-Host '----------------------------'
          Write-Host 'Collecting: ' -NoNewline
          Write-Host 'Tagged Resources' -ForegroundColor Magenta
          Invoke-TagFiltering $Subid
        }

        Write-Host '----------------------------'
        Write-Host 'Collecting: ' -NoNewline
        Write-Host 'Advisories' -ForegroundColor Magenta
        Invoke-AdvisoryExtraction $Subid

        Write-Host '----------------------------'
        Write-Host 'Collecting: ' -NoNewline
        Write-Host 'Retirements' -ForegroundColor Magenta
        Invoke-RetirementExtraction $Subid

        Write-Host '----------------------------'
        Write-Host 'Collecting: ' -NoNewline
        Write-Host 'Service Health Alerts' -ForegroundColor Magenta
        Invoke-ServiceHealthExtraction $Subid

        Write-Host '----------------------------'
        Write-Host 'Running: ' -NoNewline
        Write-Host 'Queries' -ForegroundColor Magenta
        Write-Host '----------------------------'

        if (![string]::IsNullOrEmpty($ResourceGroups)) {
          $resultAllResourceTypes = $Script:AllResources | Where-Object { $_.resourceGroup -in $ResourceGroups } | Group-Object -Property type, subscriptionId -NoElement
          $Script:AllResourceTypes += $resultAllResourceTypes
        } else {
          # Extract and display resource types with the query with subscriptions, we need this to filter the subscriptions later
          $resultAllResourceTypes = $Script:AllResources | Group-Object -Property type, subscriptionId -NoElement
          $Script:AllResourceTypes += $resultAllResourceTypes
        }

        # Create the arrays used to store the kusto queries
        $kqlQueryMap = @{}
        $aprlKqlFiles = @()
        $ServiceNotAvailable = @()

        foreach ($Type in $resultAllResourceTypes.Name) {
          $Type = $Type.split(',')[0]
          if ($Type.ToLower() -in $Script:GluedTypes) {
            $Type = $Type.replace('microsoft.', '')
            $Provider = $Type.split('/')[0]
            $ResourceType = $Type.split('/')[1]

            $Path = ''
            if ($Script:ShellPlatform -eq 'Win32NT') {
              $Path = ($clonePath + '\azure-resources\' + $Provider + '\' + $ResourceType)
              $aprlKqlFiles += Get-ChildItem -Path $Path -Filter '*.kql' -Recurse
            } else {
              $Path = ($clonePath + '/azure-resources/')
              $ProvPath = ($Provider + '/' + $ResourceType)
              $aprlKqlFiles += Get-ChildItem -Path $Path -Filter '*.kql' -Recurse | Where-Object { $_.FullName -like "*$ProvPath*" }
            }
          } else {
            $ServiceNotAvailable += $Type
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
            Invoke-QueryExecution -type ($type + ', ' + $Subid) -query $query -checkId $checkId -checkName $checkName -selector $selector -validationAction 'IMPORTANT - Query under development - Validate Recommendation manually'
          } elseif ($query -match 'cannot-be-validated-with-arg') {
            Write-Host "IMPORTANT - Recommendation $checkId cannot be validated with ARGs - Validate Resources manually" -ForegroundColor Yellow
            $query = "resources | where type =~ '$type' | project name,id"
            Invoke-QueryExecution -type ($type + ', ' + $Subid) -query $query -checkId $checkId -checkName $checkName -selector $selector -validationAction 'IMPORTANT - Recommendation cannot be validated with ARGs - Validate Resources manually'
          } else {
            Invoke-QueryExecution -type ($type + ', ' + $Subid) -query $query -checkId $checkId -checkName $checkName -selector $selector -validationAction 'Azure Resource Graph'
          }
        }

        #After processing the ARG Queries, now is time to process the -ResourceGroups
        if (![string]::IsNullOrEmpty($ResourceGroups)) {
          $TempResult = $Script:results
          $Script:results = @()

          foreach ($result in $TempResult) {
            $res = $result.id.split('/')
            if ($res[4] -in $ResourceGroups) {
              $Script:results += $result
            }
            if ($result.name -eq 'Query under development - Validate Recommendation manually') {
              $Script:results += $result
            }
          }
        }

        # Unless we're using a runbook...
        if (!($Script:RunbookChecks -and $Script:RunbookChecks.Count -gt 0)) {
          # Store all resourcetypes not in APRL
          foreach ($type in $ServiceNotAvailable) {
            Write-Host "Type $type Not Available In APRL - Validate Service manually" -ForegroundColor Yellow
            $query = "resources | where type =~ '$type' | project name,id"
            Invoke-QueryExecution -type ($type + ', ' + $Subid) -query $query -checkId $type -selector '' -checkName '' -validationAction 'IMPORTANT - Service Not Available In APRL - Validate Service manually if Applicable, if not Delete this line'
          }
        }
      }
    }
  }

  function Invoke-ResourcesExtraDetail {
    #This Function will construct the $Script:Resources variable
    $Script:Resources += foreach ($Temp in $Script:results) {
      if ($TagsFile -or $Tags) {
        if ($Temp.id -in $Script:TaggedResources.id) {
          $TempDetails = ($Script:TaggedResources | Where-Object { $_.id -eq $Temp.id } | Select-Object -First 1)
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
            tagged           = $true
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
  }

  function Resolve-ResourceType {
    $TempTypes = $Script:results | Where-Object { $_.validationAction -eq 'IMPORTANT - Service Not Available In APRL - Validate Service manually if Applicable, if not Delete this line' }
    $Script:AllResourceTypes = $Script:AllResourceTypes | Sort-Object -Property Count -Descending
    $Looper = $Script:AllResourceTypes | Select-Object -Property Name -Unique
    foreach ($result in $Looper.Name) {
      $ResourceTypeCount = ($Script:AllResourceTypes | Where-Object { $_.Name -eq $result }).count
      $ResultType = $result.split(', ')[0]
      $ResultSubID = $result.split(', ')[1]
      if ($ResultType -in $TempTypes.recommendationId) {
        $SubName = ''
        $SubName = ($SubIds | Where-Object { $_.Id -eq $ResultSubID }).Name
        $tmp = [PSCustomObject]@{
          'Subscription'        = [string]$SubName
          'Resource Type'       = [string]$ResultType
          'Number of Resources' = [string]$ResourceTypeCount
          'Available in APRL?'  = 'No'
          'Custom1'             = ''
          'Custom2'             = ''
          'Custom3'             = ''
        }
        $Script:AllResourceTypesOrdered += $tmp
      } elseif ($ResultType -notin $TempTypes.recommendationId) {
        $SubName = ''
        $SubName = ($SubIds | Where-Object { $_.Id -eq $ResultSubID }).Name
        $tmp = [PSCustomObject]@{
          'Subscription'        = [string]$SubName
          'Resource Type'       = [string]$ResultType
          'Number of Resources' = [string]$ResourceTypeCount
          'Available in APRL?'  = 'Yes'
          'Custom1'             = ''
          'Custom2'             = ''
          'Custom3'             = ''
        }
        $Script:AllResourceTypesOrdered += $tmp
      }
    }
  }

  function Invoke-AdvisoryExtraction {
    Param($Subid)
    if (![string]::IsNullOrEmpty($ResourceGroups)) {
      $Script:AllAdvisories += foreach ($RG in $ResourceGroups) {
        $advquery = "advisorresources | where type == 'microsoft.advisor/recommendations' and tostring(properties.category) == 'HighAvailability' | where resourceGroup contains '$RG' | order by id"
        $queryResults += Get-AllAzGraphResource -Query $advquery -subscriptionId $Subid

        foreach ($row in $queryResults) {
          if (![string]::IsNullOrEmpty($row.properties.resourceMetadata.resourceId)) {
            $TempResource = ''
            $TempResource = ($Script:AllResources | Where-Object { $_.id -eq $row.properties.resourceMetadata.resourceId } | Select-Object -First 1)
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
    } else {
      # Execute the query and collect the results
      $advquery = "advisorresources | where type == 'microsoft.advisor/recommendations' and tostring(properties.category) == 'HighAvailability' | order by id"
      $queryResults = Get-AllAzGraphResource -Query $advquery -subscriptionId $Subid

      $Script:AllAdvisories += foreach ($row in $queryResults) {
        if (![string]::IsNullOrEmpty($row.properties.resourceMetadata.resourceId)) {
          $TempResource = ''
          $TempResource = ($Script:AllResources | Where-Object { $_.id -eq $row.properties.resourceMetadata.resourceId } | Select-Object -First 1)
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
          Resource = $(Get-ResourceGroupsByList -ObjectList $script:results -FilterList $resourcegrouplist -KeyColumn "id")
        }
      else{
        $ResourceExporter = @{
          Resource = $Script:results
        }
      } #>

      #Ternary Expression If ResourceGroupFile is present, then get the ResourceGroups by List, else get the results
      $ResourceExporter = @{
        Resource = $ResourceGroupList ? $(Get-ResourceGroupsByList -ObjectList $Script:Resources -FilterList $resourcegrouplist -KeyColumn "id") : $Script:Resources
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


      $ExporterArray = @()
      $ExporterArray += $ResourceExporter
      $ExporterArray += $ResourceTypeExporter
      $ExporterArray += $AdvisoryExporter
      $ExporterArray += $OutageExporter
      $ExporterArray += $RetirementExporter
      $ExporterArray += $SupportExporter
      $ExporterArray += $ServiceHealthExporter
      $ExporterArray += $ScriptDetailsExporter

      $Script:JsonFile = ($PSScriptRoot + '\WARA-File-' + (Get-Date -Format 'yyyy-MM-dd-HH-mm') + '.json')

      $ExporterArray | ConvertTo-Json -Depth 15 | Out-File $Script:JsonFile
    }
  }


  #Call the functions
  $Script:Version = '2.0.11'
  Write-Host 'Version: ' -NoNewline
  Write-Host $Script:Version -ForegroundColor DarkBlue

  if ($Help.IsPresent) {
    Get-HelpMessage
    Exit
  }

    if ($ConfigFile) {
      $ConfigData = Import-ConfigFileData -file $ConfigFile
      $TenantID = $ConfigData.TenantID
      $SubscriptionIds = $ConfigData.SubscriptionIds
      $ResourceGroupList = $ConfigData.ResourceGroups
      $RunbookFile = $ConfigData.RunbookFile
      $Tags = $ConfigData.Tags
    }

    if($GUI){
      $TenantID = New-AzTenantSelection
      $SubscriptionIds = (New-AzSubscriptionSelection -TenantId $TenantID.id).id

      if($ResourceGroupGUI){
      $ResourceGroupList = (New-AzResourceGroupSelection).id.toLower()
      $ResourceGroups = $ResourceGroupList | ForEach-Object {$_.split("/")[4]}
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

  Write-Debug "Calling Function: Test-SubscriptionFile"
  Test-SubscriptionFile

  #Write-Debug "Calling Function: Invoke-PSModules"
  #Invoke-PSModules

  Write-Debug 'Calling Function: Start-ResourceExtraction'
  Start-ResourceExtraction

  Write-Debug 'Calling Function: Invoke-ResourcesExtraDetail'
  Invoke-ResourcesExtraDetail

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
