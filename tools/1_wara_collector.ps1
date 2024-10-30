#Requires -Version 7

<#
.SYNOPSIS
Well-Architected Reliability Assessment (WARA) v2 collector script

.DESCRIPTION
This script is used to collect data from Azure subscriptions to be used in the Well-Architected Reliability Assessment (WARA) v2. The script collects data from the subscriptions, resource groups, and resources, and then runs resource graph queries (Kusto/KQL) to extract information about the resources. The script also collects information about outages, support tickets, advisor recommendations, service retirements, and service health alerts. The collected data is then used to generate a JSON file with recommendations for improving the reliability of the resources/ Typically, this JSON file is used as an input for the WARA v2 data analyzer script (2_wara_data_analyzer.ps1).

By default, the script executes all relevant checks in the Azure Proactive Resiliency Library v2 but it can also be configured to run checks against specific groups of resources using a runbook (-RunbookFile).

.LINK
https://github.com/Azure/Azure-Proactive-Resiliency-Library-v2

.PARAMETER Debugging
[Switch]: Enables debugging output.

.PARAMETER TenantID
Specifies the Entra tenant ID to be used to authenticate to Azure.

.PARAMETER SubscriptionIds
Specifies the subscription IDs to be included in the review. Multiple subscription IDs should be separated by commas. Subscription IDs must be in either GUID form (e.g., 00000000-0000-0000-0000-000000000000) or full subscription ID form (e.g., /subscriptions/00000000-0000-0000-0000-000000000000).

NOTE: Can't be used in combination with -ConfigFile parameter.

.PARAMETER ResourceGroups
Specifies the resource groups to be included in the review. Multiple resource groups should be separated by commas. Resource groups must be in full resource group ID form (e.g., /subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg1).

NOTE: Can't be used in combination with -ConfigFile or -RunbookFile parameters.

.PARAMETER Tags
Specifies the tags to be used to filter resources.

NOTE: Can't be used in combination with -ConfigFile or -RunbookFile parameters.

.PARAMETER ConfigFile
Specifies the configuration file to be used.

NOTE: Can't be used in combination with -RunbookFile, -SubscriptionIds, -ResourceGroups, or -Tags parameters.

.PARAMETER AzureEnvironment
Specifies the Azure environment to be used. Valid values are 'AzureCloud' and 'AzureUSGovernment'. Default value is 'AzureCloud'.

.PARAMETER SAP
[Switch]: Enables recommendations and queries for the SAP specialized workload.

.PARAMETER AVD
[Switch]: Enables recommendations and queries for the AVD specialized workload.

.PARAMETER AVS
[Switch]: Enables recommendations and queries for the AVS specialized workload.

.PARAMETER HPC
[Switch]: Enables recommendations and queries for the HPC specialized workload.

.PARAMETER RunbookFile
Specifies the runbook file to be used. More information about runbooks:

- The parameters section defines the parameters used by the runbook. These parameters will be automatically merged into selectors and queries at runtime.
- The selectors section identifies groups of Azure resources that specific checks will be run against. Selectors can be any valid KQL predicate (e.g., resourceGroup =~ 'rg1').
- The checks section maps resource graph queries (identified by GUIDs) to specific selectors.
- The query_overrides sections enables catalogs of specialized resoruce graph queries to by included in the review.

NOTE: Can't be used in combination with -ConfigFile, -ResourceGroups, or -Tags parameters. Specify subscriptions in scope using -SubscriptionIds parameter.

.PARAMETER UseImplicitRunbookSelectors
[Switch]: Enables the use of implicit runbook selectors. When this switch is enabled, each resource graph query will be wrapped in an inner join that filters the results to only include resources that match the selector. This is useful when queries do not include selector injection comments (e.g., // selector, // selector:x).

NOTE: This parameter is only used when a runbook file (-RunbookFile) is provided.

.PARAMETER RepoUrl
Specifies the git repository URL that contains APRL contents if you want to use custom APRL repository.

.EXAMPLE
Run against all subscriptions in tenant "00000000-0000-0000-0000-000000000000":
.\1_wara_collector.ps1 -TenantID 00000000-0000-0000-0000-000000000000

.EXAMPLE
Run against specific subscriptions in tenant "00000000-0000-0000-0000-000000000000":
.\1_wara_collector.ps1 -TenantID 00000000-0000-0000-0000-000000000000 -SubscriptionIds /subscriptions/00000000-0000-0000-0000-000000000000,/subscriptions/11111111-1111-1111-1111-111111111111

.EXAMPLE
Run against specific subscriptions, resource groups, and resources defined in a configuration file:
.\1_wara_collector.ps1 -ConfigFile ".\config.json"

.EXAMPLE
Use a runbook:
.\1_wara_collector.ps1 -TenantID 00000000-0000-0000-0000-000000000000 -SubscriptionIds /subscriptions/00000000-0000-0000-0000-000000000000 -RunbookFile "runbook.json"

.OUTPUTS
A JSON file with the collected data.
#>


[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'False positive as Write-Host does not represent a security risk and this script will always run on host consoles')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '', Justification = 'False positive as parameters are not always required')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments','', Justification='Variable is reserved for future use')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars','', Justification='This will be fixed in refactor')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns','', Justification='This will be fixed in refactor')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions','', Justification='This will be fixed in refactor')]


Param(
        [switch]$Debugging,
        [switch]$SAP,
        [switch]$AVD,
        [switch]$AVS,
        [switch]$HPC,
        [ValidatePattern('^(\/subscriptions\/)?[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')]
        [String[]]$SubscriptionIds,
        [ValidatePattern('^\/subscriptions\/[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\/resourceGroups\/[a-zA-Z0-9._-]+$')]
        [String[]]$ResourceGroups,
        [GUID]$TenantID,
        [ValidatePattern('^[^<>&%\\?/]+=~[^<>&%\\?/]+$|[^<>&%\\?/]+!~[^<>&%\\?/]+$')]
        [String[]]$Tags,
        [ValidateSet('AzureCloud', 'AzureUSGovernment')]
        $AzureEnvironment = 'AzureCloud',
        [ValidateScript({Test-Path $_ -PathType Leaf})]
        $ConfigFile,
        [ValidatePattern('^https:\/\/.+$')]
        [string]$RepoUrl = 'https://github.com/Azure/Azure-Proactive-Resiliency-Library-v2',
        # Runbook parameters...
        [switch]$UseImplicitRunbookSelectors,
        $RunbookFile
        )


#import-module "./modules/collector.psm1" -Force

$Script:ShellPlatform = $PSVersionTable.Platform

if ($Tags) {$TagsPresent = $true}else{$TagsPresent = $false}

$Script:Runtime = Measure-Command -Expression {

  Function Test-TagPattern {
    param (
      [string[]]$InputValue
    )
    $pattern = '^[^<>&%\\?/]+=~[^<>&%\\?/]+$|[^<>&%\\?/]+!~[^<>&%\\?/]+$'

    $allMatch = $true

    $InputValue | ForEach-Object {
      if ($_ -notmatch $Pattern) {
        $allMatch = $false
      }
    }
    return $allMatch
  }

  Function Test-ResourceGroupId {
    param (
      [string[]]$InputValue
    )
    $pattern = '\/subscriptions\/[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\/resourceGroups\/[a-zA-Z0-9._-]+'

    $allMatch = $true

    $InputValue | ForEach-Object {
      if ($_ -notmatch $Pattern) {
        $allMatch = $false
      }
    }
    return $allMatch
  }

  Function Test-SubscriptionId {
    param (
      [string[]]$InputValue
    )
    $pattern = '\/subscriptions\/[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}'

    $allMatch = $true

    $InputValue | ForEach-Object {
      if ($_ -notmatch $Pattern) {
        $allMatch = $false
      }
    }
    return $allMatch
  }

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

  function Import-ConfigFileData($file) {
    # Read the file content and store it in a variable
    $filecontent,$linetable,$objarray,$count,$start,$stop,$configsection = $null
    $filecontent = (Get-content $file).trim().tolower()

    # Create an array to store the line number of each section
    $linetable = @()
    $objarray = [ordered]@{}

    $filecontent = $filecontent | Where-Object {$_ -ne "" -and $_ -notlike "*#*"}

    #Remove empty space.
    foreach($line in $filecontent){
        $index = $filecontent.IndexOf($line)
        if ($line -match "^\[([^\]]+)\]$" -and ($filecontent[$index+1] -match "^\[([^\]]+)\]$" -or [string]::IsNullOrEmpty($filecontent[$index+1]))) {
            # Set this line to empty because the next line is a section as well.
            $filecontent[$index] = ""
    }
}

    #Remove empty space again.
    $filecontent = $filecontent | Where-Object {$_ -ne "" -and $_ -notlike "*#*"}

    # Iterate through the file content and store the line number of each section
    foreach ($line in $filecontent) {
        if (-not [string]::IsNullOrWhiteSpace($line) -and -not $line.startswith("#")) {
            #Get the Index of the current line
            $index = $filecontent.IndexOf($line)
            # If the line is a section, store the line number
            if ($line -match "^\[([^\]]+)\]$") {
                # Store the section name and line number. Remove the brackets from the section name
                $linetable += $filecontent.indexof($line)
            }
        }
    }

    # Iterate through the line numbers and extract the section content
    $count = 0
    foreach ($entry in $linetable) {

        # Get the section name
        $name = $filecontent[$entry]
        # Remove the brackets from the section name
        $name = $name.replace("[", "").replace("]", "")

        # Get the start and stop line numbers for the section content
        # If the section is the last one, set the stop line number to the end of the file
        $start = $entry + 1

        if($linetable.count -eq $count+1){
            $stop = $filecontent.count - 1
        }else{
            $stop = $linetable[$count + 1] -1
        }


        # Extract the section content
        $configsection = $filecontent[$start..$stop]

        # Add the section content to the object array
        $objarray += @{$name = $configsection}

        # Increment the count
        $count++
    }

    # Return the object array and cast to PSCustomObject
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

  function Test-ScriptParameters {
    $IsValid = $true

    if ($RunbookFile) {

      if (!(Test-Path $RunbookFile -PathType Leaf)) {
        Write-Host "Runbook file (-RunbookFile) not found: [$RunbookFile]" -ForegroundColor Red
        $IsValid = $false
      }

      if ($ConfigFile) {
        Write-Host "Runbook file (-RunbookFile) and configuration file (-ConfigFile) cannot be used together." -ForegroundColor Red
        $IsValid = $false
      }

      if (!($SubscriptionIds)) {
        Write-Host "Subscription ID(s) (-SubscriptionIds) is required when using a runbook file (-RunbookFile)." -ForegroundColor Red
        $IsValid = $false
      }

      if ($ResourceGroups -or $Tags) {
        Write-Host "Resource group(s) (-ResourceGroups) and tags (-Tags) cannot be used with a runbook file (-RunbookFile)." -ForegroundColor Red
        $IsValid = $false
      }

    } else {

      if ($UseImplicitRunbookSelectors) {
        Write-Host "Implicit runbook selectors (-UseImplicitRunbookSelectors) can only be used with a runbook file (-RunbookFile)." -ForegroundColor Red
        $IsValid = $false
      }

      if ($ConfigFile) {

        if (!(Test-Path $ConfigFile -PathType Leaf)) {
          Write-Host "Configuration file (-ConfigFile) not found: [$ConfigFile]" -ForegroundColor Red
          $IsValid = $false
        }

        if ($SubscriptionIds -or $ResourceGroups -or $Tags) {
          Write-Host "Configuration file (-ConfigFile) and [Subscription ID(s) (-SubscriptionIds), resource group(s) (-ResourceGroups), or tags (-Tags)] cannot be used together." -ForegroundColor Red
          $IsValid = $false
        }

        if ($TenantId) {
          Write-Host "Tenant ID (-TenantId) cannot be used with a configuration file (-ConfigFile). Include tenant ID in the [tenantid] section of the config file." -ForegroundColor Red
          $IsValid = $false
        }

      } else {

        if (!($TenantId)) {
          Write-Host "Tenant ID (-TenantId) is required." -ForegroundColor Red
          $IsValid = $false
        }

        if (!($SubscriptionIds) -and !($ResourceGroups)) {
          Write-Host "Subscription ID(s) (-SubscriptionIds) or resource group(s) (-ResourceGroups) are required." -ForegroundColor Red
          $IsValid = $false
        }
      }
    }

    return $IsValid
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
            RepoUrl             = $RepoUrl
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
          git clone $Script:ScriptData.RepoUrl $clonePath --quiet
        } else {
          git clone $Script:ScriptData.RepoUrl $clonePath --quiet
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
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidatePattern("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$")]
        [GUID]$TenantID,

        [ValidateSet('AzureCloud', 'AzureChinaCloud', 'AzureGermanCloud', 'AzureUSGovernment')]
        [string]$AzureEnvironment = 'AzureCloud'
    )

    begin {
        Write-Verbose "Starting connection process to Azure Tenant."
        $AzContext = $null
    }

    process {
        try {
            # Attempt to get the current Azure context
            $AzContext = Get-AzContext -ErrorAction SilentlyContinue

            # Check if a valid context is available or if it matches the provided Tenant ID
            if ($null -eq $AzContext -or $AzContext.Tenant.Id -ne $TenantID) {
                Write-Verbose "Not logged into a tenant with any of the specified subscriptions. Authenticating to Azure. `n"

                # Check if EnableLoginByWam is true
                if ((Get-AzConfig -EnableLoginByWam).Value -eq $true) {
                    Write-Verbose "Process: Disabling interactive login experience (EnableLoginByWam).`n"
                    # Disable the WAM login experience for the current PowerShell session
                    Update-AzConfig -EnableLoginByWam $false -Scope Process | Out-Null
                }

                # Check if LoginExperienceV2 is 'On'
                if ((Get-AzConfig -LoginExperienceV2).Value -eq 'On') {
                    Write-Verbose "Process: Disabling interactive login experience (LoginExperienceV2).`n"
                    # Disable the new login experience for the current PowerShell session
                    Update-AzConfig -LoginExperienceV2 Off -Scope Process | Out-Null
                }

                Write-Verbose 'Process: Connecting to Azure.'
                Write-Verbose "No existing context found or context does not match TenantID. Connecting to Azure..."
                Connect-AzAccount -Tenant $TenantID -Environment $AzureEnvironment -ErrorAction Stop -WarningAction Ignore -InformationAction Ignore
                $AzContext = Get-AzContext -ErrorAction Stop
                Write-Verbose "Successfully connected to Azure Tenant: $TenantID"
            }
            else {
                Write-Host "`nAlready connected to Azure Tenant: $($AzContext.Tenant.Id)`n" -ForegroundColor Green
            }

            # Validate that the provided Subscription IDs exist in the current context
            $Script:SubIds = Get-AzSubscription -ErrorAction Stop -WarningAction Ignore
            Write-Verbose "Connected to Azure Tenant: $($AzContext.Tenant.Id) with Subscriptions: $($SubscriptionIds -join ', ')"
        }
        catch {
            throw "Failed to connect to Azure Tenant: $TenantID or retrieve subscriptions. Error: $_"
        }
    }

    end {
        if ($AzContext) {
            Write-Verbose "Connection process completed successfully."
        }
        else {
            throw "Connection process failed. No valid Azure context available."
        }
    }
  }

  function Test-Runbook {
    # Checks if a runbook file was provided and, if so, loads selectors and checks hashtables
    if (![string]::IsNullOrEmpty($RunbookFile)) {

      Write-Host '[-RunbookFile]: A runbook has been configured. Only checks configured in the runbook will be run.' -ForegroundColor Cyan

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
      Write-Host '[-RunbookFile]: No runbook (-RunbookFile) configured.' -ForegroundColor DarkGray
    }
  }

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

            Set-AzContext -Subscription $Subscription -ErrorAction SilentlyContinue -WarningAction SilentlyContinue | Out-Null
            Select-AzSubscription -Subscription $Subscription -WarningAction SilentlyContinue -InformationAction SilentlyContinue | Out-Null

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
            if($Debugging.IsPresent)
              {
                Write-Host $ScopeQuery -ForegroundColor Cyan
              }
            $ScopeResources = Get-AllAzGraphResource -query $ScopeQuery -subscriptionId $Subid
            foreach ($Resource in $ScopeResources)
              {
                if ($Resource.type -in $Script:SupportedResTypes)
                  {
                    if ($Resource.id -notin $Script:PreInScopeResources.id)
                      {
                        $Script:PreInScopeResources += $Resource
                      }
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
            $AdvGroup = $null
            if(![string]::IsNullOrEmpty($RGroup))
              {
                $AdvGroup = $RGroup.split("/")[4]
              }
            Invoke-AdvisoryExtraction -SubId $SubId -ResourceGroup $AdvGroup

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
        $ContainerScopeQuery = "resourceContainers | where id has '$Scope' "
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

    # Each line in the Tag Filtering file will be processed
    $AllTaggedResources = @()
    $ResetTags = $false
    Foreach ($TagLine in $TagFilter) {
      $AllTaggedResourceGroups = ''
      # Finding the TagKey and all the TagValues in the line
      if ($TagLine -like '*=~*')
        {
          $TagKeys = $TagLine.split('=~')[0]
          $TagValues = $TagLine.split('=~')[1]
        }
      elseif ($TagLine -like '*!~*')
        {
          $TagKeys = $TagLine.split('!~')[0]
          $TagValues = $TagLine.split('!~')[1]
        }

      $TagKeys = $TagKeys.split('||')
      $TagValues = $TagValues.split('||')

      $TagKey = if ($TagKeys.count -gt 1) { $TagKeys | ForEach-Object { "'$_'," } }else { $TagKeys }
      $TagKey = [string]$TagKey
      $TagKey = if ($TagKey -like "*',*") { $TagKey -replace '.$' }else { "'$TagKey'" }

      $TagValue = if ($TagValues.count -gt 1) { $TagValues | ForEach-Object { "'$_'," } }else { $TagValues }
      $TagValue = [string]$TagValue
      $TagValue = if ($TagValue -like "*',*") { $TagValue -replace '.$' }else { "'$TagValue'" }

      if ($Debugging.IsPresent)
        {
          Write-host ('Running Resource Group Tag Inventory for: ' + $TagKey + ' : ' + $TagValue)
        }

      if ($TagLine -like '*=~*')
        {
          #Getting all the Resource Groups with the Tags, this will be used later
          $RGTagQuery = "$ContainerScopeQuery | mvexpand tags | extend tagKey = tostring(bag_keys(tags)[0]) | extend tagValue = tostring(tags[tagKey]) | where tagKey in~ ($TagKey) and tagValue in~ ($TagValue) | project id | order by id"
        }
      elseif ($TagLine -like '*!~*')
        {
          $RGTagQuery = "$ContainerScopeQuery | mvexpand tags | extend tagKey = tostring(bag_keys(tags)[0]) | extend tagValue = tostring(tags[tagKey]) | where tagKey in~ ($TagKey) and tagValue !in~ ($TagValue) | project id | order by id"
        }
      $TaggedResourceGroups = Get-AllAzGraphResource -query $RGTagQuery -subscriptionId $InScopeSub
      if ($Debugging.IsPresent)
        {
          Write-host "Tagged Resource Containers Found: " -NoNewline
          $Tagged = [string]$TaggedResourceGroups.count
          write-host $Tagged -ForegroundColor Magenta
        }

        if ($TaggedResourceGroups) {
          foreach ($ResourceGroup in $TaggedResourceGroups.id) {
            if ($Debugging.IsPresent)
              {
                Write-host ('Checking Resources Inside: ' + $ResourceGroup)
              }
            $ResourcesTagQuery = "Resources | where id startswith '$ResourceGroup' | project id, name, subscriptionId, type, resourceGroup, location | order by id"

            $AllTaggedResourceGroups = Get-AllAzGraphResource -query $ResourcesTagQuery -subscriptionId $InScopeSub
          if ($Debugging.IsPresent)
            {
              Write-host "Resources Found Inside the Container: " -NoNewline
              $Tagged = [string]$AllTaggedResourceGroups.count
              write-host $Tagged -ForegroundColor Magenta
            }
          }
        }

      if ($Debugging.IsPresent)
        {
          Write-host ('Running Resource Tag Inventory for: ' + $TagKey + ' : ' + $TagValue)
        }
      if ($TagLine -like '*=~*')
        {
          #Getting all the resources within the TAGs
          $ResourcesTagQuery = "$ResourceScopeQuery | mvexpand tags | extend tagKey = tostring(bag_keys(tags)[0]) | extend tagValue = tostring(tags[tagKey]) | where tagKey in~ ($TagKey) and tagValue in~ ($TagValue) | project id, name, subscriptionId, type, resourceGroup, location | order by id"
        }
      elseif ($TagLine -like '*!~*')
        {
          $ResourcesTagQuery = "$ResourceScopeQuery | mvexpand tags | extend tagKey = tostring(bag_keys(tags)[0]) | extend tagValue = tostring(tags[tagKey]) | where tagKey in~ ($TagKey) and tagValue !in~ ($TagValue) | project id, name, subscriptionId, type, resourceGroup, location | order by id"
        }
      $ResourcesWithTHETag = Get-AllAzGraphResource -query $ResourcesTagQuery -subscriptionId $InScopeSub

      if ($Debugging.IsPresent)
        {
          Write-host "Tagged Resources Found: " -NoNewline
          $Tagged = [string]$ResourcesWithTHETag.count
          write-host $Tagged -ForegroundColor Magenta
        }

        if (![string]::IsNullOrEmpty($ResourcesWithTHETag) -and [string]::IsNullOrEmpty($AllTaggedResources) -and $ResetTags -eq $false)
          {
            $AllTaggedResources += $ResourcesWithTHETag
            $AllTaggedResources += $AllTaggedResourceGroups
          }
        elseif ([string]::IsNullOrEmpty($ResourcesWithTHETag) -and ![string]::IsNullOrEmpty($AllTaggedResourceGroups))
          {
            $AllTaggedResources += $AllTaggedResourceGroups
          }
        elseif ([string]::IsNullOrEmpty($ResourcesWithTHETag) -and [string]::IsNullOrEmpty($AllTaggedResourceGroups))
          {
            if ($Debugging.IsPresent)
              {
                Write-host "No Tagged Resources were found. Reseting Values."
              }
            $AllTaggedResources = @()
            $ResetTags = $true
          }
        elseif (![string]::IsNullOrEmpty($AllTaggedResources) -and $ResetTags -eq $false)
          {
            foreach ($resource in $AllTaggedResources)
              {
                if ($resource.id -notin $ResourcesWithTHETag.id)
                  {
                    $AllTaggedResources = $AllTaggedResources | Where-Object { $_.id -ne $resource.id }
                  }
              }
          }
      }
        $Script:TaggedResources += $AllTaggedResources | Select-Object -Property id, name, subscriptionId, type, resourceGroup, location -Unique -CaseInsensitive
        if ($Debugging.IsPresent)
          {
            Write-host "Tagged Resources Final Value: " -NoNewline
            $Tagged = [string]$Script:TaggedResources.count
            write-host $Tagged -ForegroundColor Magenta
          }
  }

  function Invoke-QueryExecution {
    param($type, $Subscription, $query, $checkId, $checkName, $selector, $validationAction)

    if ($Debugging.IsPresent)
      {
        Write-Host $query -ForegroundColor Yellow
      }

    try {
      $ResourceType = $Script:AllResourceTypes | Where-Object { $_.Name -eq $type}
      if (![string]::IsNullOrEmpty($resourceType)) {
        # Execute the query and collect the results
        # $queryResults = Search-AzGraph -Query $query -First 1000 -Subscription $Subid -ErrorAction SilentlyContinue
        $queryResults = Get-AllAzGraphResource -query $query -subscriptionId $Subscription

        $queryResults = $queryResults | Sort-Object -Property name, id, param1, param2, param3, param4, param5 -Unique

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

    $TempResult = @()
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
            Write-Host "[-RunbookFile]: Loading [$($queryOverridePath)] query overrides..." -ForegroundColor Cyan

            $overrideKqlFiles = Get-ChildItem -Path $queryOverridePath -Filter '*.kql' -Recurse

            foreach ($overrideKqlFile in $overrideKqlFiles) {
              if ($Script:ShellPlatform -eq 'Win32NT') {
                $kqlShort = [string]$overrideKqlFile.FullName.split('\')[-1]
              } else {
                $kqlShort = [string]$overrideKqlFile.FullName.split('/')[-1]
              }
              $kqlName = $kqlShort.split('.')[0]

              if ($kqlQueryMap.ContainsKey($kqlName)) {
                Write-Host "[-RunbookFile]: Original [$kqlName] APRL query overridden by [$($overrideKqlFile.FullName)]." -ForegroundColor Cyan
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

          $kqltype = ('Microsoft.' + $typeRaw[-3] + '/' + $typeRaw[-2])
          $checkId = $kqlname.Split('/')[-1].ToLower()

          if ($Script:RunbookChecks -and $Script:RunbookChecks.Count -gt 0) {
            # A runbook has been provided...

            if ($Script:RunbookChecks.ContainsKey($checkId)) {
              # A check has been configured in the runbook for this query...

              $runbookCheckCt = 0

              $check = $Script:RunbookChecks[$checkId]

              $check.PSObject.Properties | ForEach-Object {
                $checkName = $_.Name
                $defaultSelectorName = $_.Value

                if ($Script:RunbookSelectors.ContainsKey($defaultSelectorName)) {
                  # If a matching selector exists, add a new query to the queries array
                  # that includes the appropriate selector...

                  $selectorQuery = $baseQuery

                  # Resolve named selectors...
                  foreach ($selectorKey in $Script:RunbookSelectors.Keys) {
                    $namedSelector = $Script:RunbookSelectors[$selectorKey]
                    $selectorQuery = $selectorQuery.Replace("// selector:$selectorKey", "| where $namedSelector")
                    $selectorQuery = $selectorQuery.Replace("//selector:$selectorKey", "| where $namedSelector")
                  }

                  # Then, resolve any default selectors...
                  $checkSelector = $Script:RunbookSelectors[$defaultSelectorName]
                  $selectorQuery = $selectorQuery.Replace('//selector', "| where $checkSelector")
                  $selectorQuery = $selectorQuery.Replace('// selector', "| where $checkSelector")

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
                    selector  = [string]$defaultSelectorName
                    query     = [string]$selectorQuery
                    type      = [string]$kqltype
                  }

                  $runbookCheckCt++

                } else {
                  Write-Host "[-RunbookFile]: Selector $selectorName not found in runbook. Skipping check..." -ForegroundColor Yellow
                }
              }

              if ($queries.Count -gt 0) {
                Write-Host "[-RunbookFile]: There are $runbookCheckCt runbook check(s) configured for $checkId. Running checks..." -ForegroundColor Cyan
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
            Write-Host "[APRL]: $type - $checkId" -ForegroundColor Green -NoNewline
          } else {
            Write-Host "[-RunbookFile]: [$checkName (selector: '$selector')]: $checkId" -ForegroundColor Green -NoNewline
          }
          Write-Host ' +++++++++++++++'

          # Validating if Query is Under Development
          if ($query -match 'development') {
            Write-Host "Query $checkId under development - Validate Recommendation manually" -ForegroundColor Yellow
            $query = "resources | where type =~ '$type' | project name,id"
            $TempResult += Invoke-QueryExecution -type $type -Subscription $Subid -query $query -checkId $checkId -checkName $checkName -selector $selector -validationAction 'IMPORTANT - Query under development - Validate Resources manually'
          } elseif ($query -match 'cannot-be-validated-with-arg') {
            Write-Host "IMPORTANT - Recommendation $checkId cannot be validated with ARGs - Validate Resources manually" -ForegroundColor Yellow
            $query = "resources | where type =~ '$type' | project name,id"
            $TempResult += Invoke-QueryExecution -type $type -Subscription $Subid -query $query -checkId $checkId -checkName $checkName -selector $selector -validationAction 'IMPORTANT - Recommendation cannot be validated with ARGs - Validate Resources manually'
          } else {
            $TempResult += Invoke-QueryExecution -type $type -Subscription $Subid -query $query -checkId $checkId -checkName $checkName -selector $selector -validationAction 'APRL - Queries'
          }
        }

        if ($Scope.split("/").count -gt 4 -and $Scope.split("/").count -lt 8)
          {
            if(![string]::IsNullOrEmpty($TempResult)){
              $Script:results += Get-ResourceGroupsByList -ObjectList $TempResult -FilterList $Scope -KeyColumn "id"
            }

          }
        else
          {
            if(![string]::IsNullOrEmpty($TempResult)){
            $Script:results += $TempResult
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

  Function Invoke-FilterResourceID {
    [cmdletbinding()]
    Param(
        $ResourceID,
        $List
    )
    ForEach ($item in $List){
        If ($ResourceID -eq $Item.id){$item}
    }
}

  function Invoke-ResourceFiltering {
    if ($Tags) {
      Write-Host "Filtering Resources In-Scope for Tag Filtering.." -ForegroundColor Cyan
      $Script:InScope = foreach ($Resource in $Script:PreInScopeResources)
        {
          if ($Resource.id -in $Script:TaggedResources.id)
            {
              $Resource
            }
        }
      }
    else
        {
          Write-Host "Selecting In-Scope Resources.." -ForegroundColor Cyan
          $Script:InScope = $Script:PreInScopeResources
      }

    if (![string]::IsNullOrEmpty($Script:ExcludeList))
      {
        Write-Host "Filtering Excluded Resources.." -ForegroundColor Cyan
        $Script:InScope = $Script:InScope | Where-Object {$_.id -notin $Script:ExcludeList.id}
      }

    Write-Host "Ordering Impacted Resources.." -ForegroundColor Cyan
    $Script:results = $Script:results | Sort-Object -Unique -Property validationAction, recommendationId, name, Type, id, param1, param2, param3, param4, param5, checkName, selector

    Write-Host "Filtering Impacted Resources.." -ForegroundColor Cyan
    $Script:ImpactedResources = foreach ($Temp in $Script:results)
      {
        $TempResID = $Temp.id.split('/')
        $TempResID = ('/'+$TempResID[1]+ '/'+ $TempResID[2]+ '/'+ $TempResID[3]+ '/'+ $TempResID[4]+ '/'+ $TempResID[5]+ '/'+ $TempResID[6]+ '/'+ $TempResID[7]+ '/'+ $TempResID[8])

        if ($Temp.id -eq "n/a") {
          $result = [PSCustomObject]@{
            validationAction = $Temp.validationAction
            recommendationId = $Temp.recommendationId
            name             = 'n/a'
            id               = 'n/a'
            type             = 'n/a'
            location         = 'n/a'
            subscriptionId   = 'n/a'
            resourceGroup    = 'n/a'
            param1           = $Temp.param1
            param2           = $Temp.param2
            param3           = $Temp.param3
            param4           = $Temp.param4
            param5           = $Temp.param5
            checkName        = $Temp.checkName
            selector         = $Temp.selector
          }
          $result
        }
        elseif ($TempResID -in $Script:InScope.id)
          {
              $TempDetails = Invoke-FilterResourceID -Resource $TempResID -List $Script:PreInScopeResources
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
            }
    }

    $Script:ImpactedResources = $Script:ImpactedResources | Sort-Object -Unique -Property validationAction, recommendationId, name, Type, id, param1, param2, param3, param4, param5, checkName, selector

    Write-Host "Filtering Advisor Resources.." -ForegroundColor Cyan
    $Script:Advisories = foreach ($adv in $Script:AllAdvisories)
      {
        if ($adv.id -in $Script:InScope.id)
          {
            $adv
          }
      }

    Write-Host "Filtering Out of Scope Resources.." -ForegroundColor Cyan
    $Script:OutOfScope = foreach ($ResIID in $Script:PreOutOfScopeResources)
      {
        if ($Tags)
          {
            if ($ResIID.id -in $Script:TaggedResources.id)
            {
              $result = [PSCustomObject]@{
                description      = 'No Action Required - This ResourceType is already covered by its Parent ResourceType, or is out of scope of Well-Architected Reliability Assessment engagements.'
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
        else
          {
            $result = [PSCustomObject]@{
              description      = 'No Action Required - This ResourceType is already covered by its Parent ResourceType, or is out of scope of Well-Architected Reliability Assessment engagements.'
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
    $Looper = $Script:AllResourceTypes | Sort-Object -Property Name -Unique
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
        $advquery = "advisorresources | where type == 'microsoft.advisor/recommendations' and tostring(properties.category) in ('HighAvailability') | where resourceGroup =~ '$ResourceGroup' | order by id"
        $queryResults = Get-AllAzGraphResource -Query $advquery -subscriptionId $Subid
      } else {
        $advquery = "advisorresources | where type == 'microsoft.advisor/recommendations' and tostring(properties.category) in ('HighAvailability') | order by id"
        $queryResults = Get-AllAzGraphResource -Query $advquery -subscriptionId $Subid
      }

      $loopAdvisories = foreach ($row in $queryResults) {
        if (![string]::IsNullOrEmpty($row.properties.resourceMetadata.resourceId)) {
          $TempResource = ''
          $TempResource = Invoke-FilterResourceID -ResourceID $row.properties.resourceMetadata.resourceId -List $Script:PreInScopeResources
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
      $Script:AllAdvisories = $loopAdvisories
  }

  function Resolve-SupportTicket {
    $Tickets = $Script:SupportTickets
    $Script:SupportTickets = @()
    $Script:SupportTickets = foreach ($Ticket in $Tickets) {
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

    $Script:AllRetirements = foreach ($row in $queryResults) {
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
    $Rowler = foreach ($row in $queryResults) {
      foreach ($type in $row.properties.condition.allOf) {
        if ($type.equals -eq 'ServiceHealth') {
          $row
        }
      }
    }

    $Script:AllServiceHealth = foreach ($Row in $Rowler) {
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
      Write-Host $ResourceGroups -ForegroundColor Yellow

      $ResourceExporter = @{
        ImpactedResources = $Script:ImpactedResources
      }
      $OutOfScopeExporter = @{
        OutOfScope = $Script:OutOfScope
      }
      $ResourceTypeExporter = @{
        ResourceType = $Script:AllResourceTypesOrdered
      }
      $AdvisoryExporter = @{
        Advisory = $Script:Advisories
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
  $Script:Version = '2.1.16'
  Write-Host 'Version: ' -NoNewline
  Write-Host $Script:Version -ForegroundColor DarkBlue

  Write-Debug "Checking parameters..."

  if (!(Test-ScriptParameters)) {
    Write-Host 'Invalid parameters. Exiting...' -ForegroundColor Red
    Exit
  }

  if ($ConfigFile) {
    $Scopes = @()
    $ConfigData = Import-ConfigFileData -file $ConfigFile
    $TenantID = $ConfigData.TenantID | Select-Object -First 1
    $Scopes += foreach ($SubscriptionId in $ConfigData.subscriptionids)
      {
        if ((Test-SubscriptionId $SubscriptionId))
          {
            $SubscriptionId
          }
        else
          {
            Write-Host 'Invalid Subscription parameters. Exiting...' -ForegroundColor Red
            Exit
          }
      }
    $Scopes += foreach ($resourcegroup in $ConfigData.resourcegroups)
      {
        if ((Test-ResourceGroupId $resourcegroup))
          {
            $resourcegroup
          }
        else
          {
            Write-Host 'Invalid ResourceGroup parameters. Exiting...' -ForegroundColor Red
            Exit
          }
      }
    $Scopes += $ConfigData.resources
    $locations = $ConfigData.locations
    $RunbookFile = $ConfigData.RunbookFile
    if ($ConfigData.Tags)
      {
        $Tags = foreach ($tag in $ConfigData.Tags)
          {
            if ((Test-TagPattern $tag))
              {
                $tag
              }
            else
              {
                Write-Host 'Invalid Tag parameters. Exiting...' -ForegroundColor Red
                Exit
              }
          }
      }
  }
  else {
    $Scopes = @()
    if ($SubscriptionIds)
      {
        $Scopes += foreach ($Sub in $SubscriptionIds)
        {
          $_guid = [Guid]::NewGuid()

          if ([Guid]::TryParse($Sub, [ref]$_guid)) {
            $SubId = "/subscriptions/$Sub"
            Write-Host "[-SubscriptionIds]: Fixed '$Sub' >> '$SubId'" -ForegroundColor Yellow
            "/subscriptions/$Sub" # Fixed!
          } else {
            Write-Host "[-SubscriptionIds]: $Sub" -ForegroundColor Cyan
            $Sub
          }
        }
      }
    if ($ResourceGroups)
      {
        $Scopes += foreach ($RG in $ResourceGroups)
          {
            Write-Host "[-ResourceGroups]: $RG" -ForegroundColor Cyan
            $RG
          }
      }
  }

  Write-Debug 'Reseting Variables'
  Invoke-ResetVariable

  Write-Debug 'Calling Function: Test-Requirements'
  Test-Requirement

  Write-Debug 'Calling Function: Set-LocalFiles'
  Set-LocalFile

  Write-Debug 'Calling Function: Test-Runbook'
  Test-Runbook

  Write-Debug "Calling Function: Connect-ToAzure"
  Connect-ToAzure -TenantID $TenantID -AzureEnvironment $AzureEnvironment

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
