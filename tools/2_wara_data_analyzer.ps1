#Requires -Version 7

<#
.SYNOPSIS
Well-Architected Reliability Assessment Script

.DESCRIPTION
The script "2_wara_data_analyzer" will process the JSON file created by the "1_wara_collector" script and will edit the Expert-Analysis Excel file.

.PARAMETER Help
Switch to display help information.

.PARAMETER RepositoryUrl
Specifies the git repository URL that contains APRL contents if you want to use custom APRL repository.

.PARAMETER JSONFile
Path to the JSON file created by the "1_wara_collector" script.

.PARAMETER ExpertAnalysisFile
Path to the Expert-Analysis file to be customized by script.

.EXAMPLE
.\2_wara_data_analyzer.ps1 -JSONFile 'C:\Temp\WARA_File_2024-04-01_10_01.json' -ExpertAnalysisFile 'C:\Temp\Expert-Analysis-v1.xlsx'

.LINK
https://github.com/Azure/Azure-Proactive-Resiliency-Library-v2
#>

Param(
[ValidatePattern('^https:\/\/.+$')]
[string] $RepositoryUrl = 'https://github.com/Azure/Azure-Proactive-Resiliency-Library-v2',
[string] $CustomRecommendationsYAMLPath,
[Parameter(mandatory = $true)]
[string] $JSONFile,
[string] $ExpertAnalysisFile
)

# Check if the Expert-Analysis file exists
$CurrentPath = Get-Location
$CurrentPath = $CurrentPath.Path
if (!$ExpertAnalysisFile)
	{
		Write-Debug ((get-date -Format 'yyyy-MM-dd HH:mm:ss') + (' - Testing: ' + $CurrentPath + '\Expert-Analysis-v1.xlsx'))
		if ((Test-Path -Path ($CurrentPath + '\Expert-Analysis-v1.xlsx') -PathType Leaf) -eq $true) {
			$ExpertAnalysisFile = ($CurrentPath + '\Expert-Analysis-v1.xlsx')
		}
	}
else
{
	Write-Host ""
	Write-Host "This script requires specific Microsoft Excel templates, which are available in the Azure Proactive Resiliency Library. You can download the templates from this GitHub repository:"
	Write-Host "https://github.com/Azure/Azure-Proactive-Resiliency-Library-v2/tree/main/tools" -ForegroundColor Yellow
	Write-Host ""
	Throw "The Expert-Analysis file does not exist. Please provide a valid path to the Expert-Analysis file."
	Exit
}

if ((Test-Path -Path $ExpertAnalysisFile -PathType Leaf) -eq $true) {
	$ExpertAnalysisFile = (Resolve-Path -Path $ExpertAnalysisFile).Path
}
else
{
	Write-Host ""
	Write-Host "This script requires specific Microsoft Excel templates, which are available in the Azure Proactive Resiliency Library. You can download the templates from this GitHub repository:"
	Write-Host "https://github.com/Azure/Azure-Proactive-Resiliency-Library-v2/tree/main/tools" -ForegroundColor Yellow
	Write-Host ""
	Throw "The Expert-Analysis file does not exist. Please provide a valid path to the Expert-Analysis file."
	Exit
}


# Check if the JSON file exists 
if ((Test-Path -Path $JSONFile -PathType Leaf) -eq $true) {
	$JSONFile = (Resolve-Path -Path $JSONFile).Path
}
else
{
	Throw "JSON file not found. Please provide a valid path to the JSON file."
	Exit
}

$TableStyle = 'Light19'

$Runtime = Measure-Command -Expression {

# function validate if the required modules are installed
function Test-Requirement {
	# Install required modules
	Write-Host 'Validating ' -NoNewline
	Write-Host 'ImportExcel' -ForegroundColor Cyan -NoNewline
	Write-Host ' Module..'
	$ImportExcel = Get-Module -Name ImportExcel -ListAvailable -ErrorAction silentlycontinue
	if ($null -eq $ImportExcel) {
		Write-Host 'Installing ImportExcel Module' -ForegroundColor Yellow
		Install-Module -Name ImportExcel -Force -SkipPublisherCheck
	}
	Write-Host 'Validating ' -NoNewline
	Write-Host 'Powershell-YAML' -ForegroundColor Cyan -NoNewline
	Write-Host ' Module..'
	$AzModules = Get-Module -Name powershell-yaml -ListAvailable -ErrorAction silentlycontinue
	if ($null -eq $AzModules) {
		Write-Host 'Installing Az Modules' -ForegroundColor Yellow
		Install-Module -Name powershell-yaml -SkipPublisherCheck -InformationAction SilentlyContinue
	}
	Write-Host 'Validating ' -NoNewline
	Write-Host 'Git' -ForegroundColor Cyan -NoNewline
	Write-Host ' Installation..'
	$GitVersion = git --version
	if ($null -eq $GitVersion) {
		Write-Host 'Missing Git' -ForegroundColor Red
		Exit
	}
}

# function to read the JSON file
function Read-JSONFile
{
	Param
	(
		[Parameter(Mandatory = $true)]
		[string]$JSONFile
	)

	Write-Debug ((get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Starting to Read the JSON file')
	$JSONResources = Get-Item -Path $JSONFile
	$JSONResources = $JSONResources.FullName
	$JSONContent = Get-Content -Path $JSONResources | ConvertFrom-Json
	Write-Debug ((get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - JSON File Created with version: ' + $JSONContent.ScriptDetails.Version)
	Write-Debug ((get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Raw ImpactedResources found: ' + $JSONContent.ImpactedResources.Count)
	Write-Debug ((get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Raw PlatformIssues found: ' + $JSONContent.Outages.Count)
	Write-Debug ((get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Raw SupportTickets found: ' + $JSONContent.SupportTickets.Count)
	Write-Debug ((get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Raw Workload Inventory found: ' + $JSONContent.InScopeResources.Count)
	return $JSONContent
}

# function to clone the github repository
function Copy-RepositoryFiles
{
	Param
	(
		[Parameter(Mandatory = $true)]
		[string]$RepoUrl
	)
	$RepoFolder = $RepoUrl.split('/')[-1]
	# Settings location to create the repository folder
	$workingFolderPath = Get-Location
	$workingFolderPath = $workingFolderPath.Path
	$clonePath = "$workingFolderPath\$RepoFolder"
	Write-Debug ((get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Checking Default Folder')
	if ((Test-Path -Path $clonePath -PathType Container) -eq $true) {
		Write-Debug ((get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Repository Folder does exist. Reseting it...')
		Get-Item -Path $clonePath | Remove-Item -Recurse -Force
		Write-host 'Downloading repository: ' -NoNewline
		Write-Host $RepoUrl -ForegroundColor Yellow
		git clone $RepoUrl $clonePath --quiet
	} else {
		Write-host 'Downloading repository: ' -NoNewline
		Write-Host $RepoUrl -ForegroundColor Yellow
		git clone $RepoUrl $clonePath --quiet
	}
	return $clonePath
}

function Save-WARAExcelFile
{
	Param(
		[string]$ExpertAnalysisFile
		)

	$workingFolderPath = Get-Location
	$workingFolderPath = $workingFolderPath.Path
	$ExcelPkg = Open-ExcelPackage -Path $ExpertAnalysisFile
	$NewExpertAnalysisFile = ($workingFolderPath + '\Expert-Analysis-v1-' + (Get-Date -Format 'yyyy-MM-dd-HH-mm') + '.xlsx')
	Close-ExcelPackage -ExcelPackage $ExcelPkg -SaveAs $NewExpertAnalysisFile

	return $NewExpertAnalysisFile
}

# function responsible to read the YAML files
function Get-WARARecommendationList
{
	Param
	(
		[Parameter(Mandatory = $true)]
		[string]$Path
	)

	Write-Debug ((get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Processing YAML files from: ' + $Path)
	$YAMLFiles = Get-ChildItem -Path $Path -Filter 'recommendations.yaml' -Recurse

	$YAMLContent = @()
	foreach ($YAML in $YAMLFiles) {
		if (![string]::IsNullOrEmpty($YAML)) {
			$YAMLContent += Get-Content -Path $YAML | ConvertFrom-Yaml
		}
	}

	return $YAMLContent	

}

# function to process the standard WARA message in the column A
function Get-WARAMessage 
{
	Param($Message)

if ($Message -eq 'ImpactedResources_Type')
{
$WARAMessage = @"
REQUIRED ACTIONS: ResourceType not available in APRL/Advisor.
This Resource Type does not have recommendations in APRL or Advisor, then follow these steps:
1. Manually validate this resource and create your own resiliency and/or reliability-related recommendations, if applicable.
2. When creating a new recommendation, ensure the following fields are populated: Title, Impact, Potential Benefit, Description, ResourceType, and Learn More Link.
3. Duplicate this row if you need to create more than one recommendation for the same resource.
4. If the resource is not compliant with your recommendation,  update this cell to "Reviewed".
or
5. Delete this row if this resource is irrelevant or is already compliant with your recommendation.
"@
}

if ($Message -eq 'ImpactedResources_Unavailable')
{
$WARAMessage = @"
REQUIRED ACTIONS: Recommendation does not have automated validation.
This recommendation does not have automated validation. Since it cannot be validated automatically, follow these steps:
1. Review the Recommendation Title and Description to understand the recommendation. Use the "Read More" links for additional information.
2. Open the Azure Portal and locate the potentially impacted resource using its Resource Name or ResourceId.
3. Manually validate the resource.
4. If the resource is not compliant with the recommendation, update this cell to "Reviewed".
or
5. Delete this row if the resource is irrelevant or already compliant with the recommendation.
"@
}

if ($Message -eq 'ImpactedResources_ServiceRetirement')
{
$WARAMessage = @"
REQUIRED ACTIONS: Azure Service Health - Service Retirements.
This Service Health Retirement Notification was automatically imported to your workload review according to the Subscriptions being assessed and Services being used.
1. Review and if necessary summarize the cell "Recommendation Title."
2. Retrieve the Resource Name and Resource ID of the impacted resources from the Azure Portal.
3. If more resources are associated with the same Service Retirement Notification, duplicate this row and update it with the Resource Name and Resource ID for all applicable resources.
4. Once completed, update this cell to "Reviewed".
or
5. If this Service Retirement Notification is not relevant, delete this row.
"@
}

if ($Message -eq 'ImpactedResources_Architecture')
{
$WARAMessage = @"
REQUIRED ACTIONS: Architectural and Reliability Design Patterns Recommendations
This row is just an example. Modify it and create your own personalized recommendations for architecture and/or reliability design patterns.
1. Create new custom recommendations based on the Discovery Workshop Questionnaire.
2. Associate it with the SubscriptionId and "Microsoft.Subscription/Subscriptions" as the associated "resourceType", or any resource and ResourceType that you consider applicable.
3. Once completed, update this cell to "Reviewed".
or
4. Delete this row if no personalized/custom recommendations will be provided.
"@
}

if ($Message -eq 'ImpactedResources_WAF')
{
$WARAMessage = @"
REQUIRED ACTIONS: Well-Architected Framework.
This is a generic recommendation from the Well-Architected Framework - Reliability pillar. It cannot be validated automatically and need information from the Discovery Workshop session.
1. Review and update this row based on the Discovery Workshop Questionnaire.
2. If this recommendation is applicable, update the "Impact" column according to the importance for the Workload and then update this cell to "Reviewed".
or
3. If this recommendation is not relevant, delete this row.
"@
}

if ($Message -eq 'PlatformIssues_Standard')
{
$WARAMessage = @"
REQUIRED ACTIONS: Review Platform Issue and create recommendations.
This Platform Issue may have affected the workload, since it cannot be validated automatically, follow these steps:
1. Review all information about the Platform Issue.
2. Discuss with the Account Team/Workload Owner if this Platform Issue affected the workload and how, you can also check if there are associated Support Requests.
3. If this issue affected the workload, create recommendations in the "3.ImpactedResources" worksheet based on the "How can customers make incidents like this less impactful" field. You can associate the recommendation(s) with the Workload or individual resources.
4. If the recommendation(s) already exists, simply add the TrackingID to the respective column of the associated Recommendation(s).
or
5. Delete this row if the workload was not affected by this Platform Issue.
"@
}

if ($Message -eq 'SupportTickets_Standard')
{
$WARAMessage = @"
REQUIRED ACTIONS: Review Customer Support Requests and create recommendations.
This Customer Support Request is associated with the Subscription of the workload, since it cannot be validated automatically, follow these steps:
1. Review all information about the Support Request in the Azure Portal.
2. Discuss with Workload Owner if this Support Request affected the workload and how.
3. If this Support Request was relevant for the workload, create recommendations in the "3.ImpactedResources" worksheet based on it was resolved. You can associate the recommendation(s) with the Workload or individual resources. The goal is to make sure other resources or services follow the Microsoft recommendation/solution and prevent this incident from happening again.
4. If the recommendation(s) already exists, simply add the TicketID to the respective column of the associated Recommendation(s).
or
5. Delete this row if the workload was not affected, associated with this Support Request.
"@
}

return $WARAMessage
}

<############################## Impacted Resources #########################################>

function Initialize-WARAImpactedResources
{
	Param(
		[Parameter(mandatory = $true)]
		$ImpactedResources,
		[Parameter(mandatory = $true)]
		$Advisory,
		[Parameter(mandatory = $true)]
		$Retirements,
		[Parameter(mandatory = $true)]
		$ScriptDetails
	)

	$ServicesYAMLContent = @()
	if (![string]::IsNullOrEmpty($CustomRecommendationsYAMLPath)) {
		Write-Debug ((get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Getting Recommendations from Custom Path')
		$ServicesYAMLContent = Get-WARARecommendationList -Path $CustomRecommendationsYAMLPath
	}

	Write-Debug ((get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Getting Recommendations from the standard azure-resources')
	$ServicesYAMLContent += Get-WARARecommendationList -Path ($clonePath + '\azure-resources')
	Write-Debug ((get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Getting Recommendations from the standard azure-waf')
	$WAFYAMLContent = Get-WARARecommendationList -Path ($clonePath + '\azure-waf')

	if ($ScriptDetails.SAP -eq 'True') {
		Write-Debug ((get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Getting Recommendations from SAP')
		$ServicesYAMLContent += Get-WARARecommendationList -Path ($clonePath + '\azure-specialized-workloads\sap')
	}
	if ($ScriptDetails.AVD -eq 'True') {
		Write-Debug ((get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Getting Recommendations from AVD')
		$ServicesYAMLContent += Get-WARARecommendationList -Path ($clonePath + '\azure-specialized-workloads\avd')
	}
	if ($ScriptDetails.AVS -eq 'True') {
		Write-Debug ((get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Getting Recommendations from AVS')
		$ServicesYAMLContent += Get-WARARecommendationList -Path ($clonePath + '\azure-specialized-workloads\avs')
	}
	if ($ScriptDetails.HPC -eq 'True') {
		Write-Debug ((get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Getting Recommendations from HPC')
		$ServicesYAMLContent += Get-WARARecommendationList -Path ($clonePath + '\azure-specialized-workloads\hpc')
	}

	Write-Debug ((get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Overall YAML Recommendations found: ' + [string]$ServicesYAMLContent.Count)

	# Filtering the recommendations to get only the active ones and the ones that are not already in the advisories list
	Write-Debug ((get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Filtering Active Recommendations and Recommendations not in Advisories')
	$RecommendationYAMLContent = $ServicesYAMLContent | Where-Object {($_.recommendationMetadataState -eq 'Active' -and $_.recommendationTypeId -notin $JSONContent.Advisory.recommendationId) }

	Write-Debug ((get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - YAML Recommendations After Filtering: ' + [string]$RecommendationYAMLContent.Count)

	#$RecommendationYAMLContent | where {$_.aprlGuid -eq 'b60ae773-9917-4bca-8a42-7cb45365a917'}

	$tmp = @()

	# First loop through the recommendations to get the impacted resources
	foreach ($Recom in $RecommendationYAMLContent)
		{
			# Getting the impacted resources for the recommendation and validating if the recommendation is a Custom Recommendation
			$Resources = $ImpactedResources | Where-Object {($_.recommendationId -eq $Recom.aprlGuid) -and ($_.checkName -eq $Recom.checkName) }

			# If the recommendation is not a Custom Recommendation, we need to validate if the resources are not already in the tmp array (from a previous loop of a Custom Recommendation)
			if ([string]::IsNullOrEmpty($Resources) -and $Recom.aprlGuid -notin $tmp.Guid)
			{
				$Resources = $ImpactedResources| Where-Object {($_.recommendationId -eq $Recom.aprlGuid) }
			}

			foreach ($Resource in $Resources)
			{
				
				$ValidationMSG = if($Resource.validationAction -eq 'IMPORTANT - Query under development - Validate Resources manually') 
					{
						Get-WARAMessage -Message 'ImpactedResources_Unavailable'
					} 
				else {
					if ($Resource.validationAction -eq 'IMPORTANT - Resource Type is not available in either APRL or Advisor - Validate Resources manually if Applicable, if not Delete this line')
					{
						Get-WARAMessage -Message 'ImpactedResources_Type'
					}
					else
					{
						'Pending'
					}
				}

				$obj = @{
					'REQUIRED ACTIONS / REVIEW STATUS' = $ValidationMSG;
					'ValidationCategory' = 'Resource';
					'Resource Type' = $Resource.type;
					'subscriptionId' = $Resource.subscriptionId;
					'resourceGroup' = $Resource.resourceGroup;
					'location' = $Resource.location;
					'name' = $Resource.name;
					'id' = $Resource.id;
					'custom1' = $Resource.param1;
					'custom2' = $Resource.param2;
					'custom3' = $Resource.param3;
					'custom4' = $Resource.param4;
					'custom5' = $Resource.param5;
					'Recommendation Title' = $Recom.description;
					'Impact' = $Recom.recommendationImpact;
					'Recommendation Control' = ($Recom.recommendationControl -csplit '(?=[A-Z])' -ne '' -join ' ');
					'Potential Benefit' = $Recom.potentialBenefits;
					'Learn More Link' = ($Recom.learnMoreLink.url -join " `n");
					'Long Description' = $Recom.longDescription;
					'Guid' = $Recom.aprlGuid;
					'Category' = 'Azure Service';
					'Source' = $Resource.selector;
					'WAF Pillar' = 'Reliability';
					'Platform Issue TrackingId' = '';
					'Retirement TrackingId' = '';
					'Support Request Number' = '';
					'Notes' = '';
					'checkName' = $Resource.checkName
				}
				$tmp += $obj
			}
		}

	# Second loop through the advisories to get the impacted resources
	$ADVMessage = Get-WARAMessage -Message 'ImpactedResources_Unavailable'
	foreach ($adv in $Advisory)
		{
			if (![string]::IsNullOrEmpty($adv))
				{
					$obj = @{
						'REQUIRED ACTIONS / REVIEW STATUS' = $ADVMessage;
						'ValidationCategory' = 'Resource';
						'Resource Type' = $adv.type;
						'subscriptionId' = $adv.subscriptionId;
						'resourceGroup' = $adv.resourceGroup;
						'location' = $adv.location;
						'name' = $adv.name;
						'id' = $adv.id;
						'custom1' = '';
						'custom2' = '';
						'custom3' = '';
						'custom4' = '';
						'custom5' = '';
						'Recommendation Title' = $adv.description;
						'Impact' = $adv.impact;
						'Recommendation Control' = ($adv.category -csplit '(?=[A-Z])' -ne '' -join ' ');
						'Potential Benefit' = '';
						'Learn More Link' = '';
						'Long Description' = '';
						'Guid' = $adv.recommendationId;
						'Category' = '';
						'Source' = 'ADVISOR';
						'WAF Pillar' = 'Reliability';
						'Platform Issue TrackingId' = '';
						'Retirement TrackingId' = '';
						'Support Request Number' = '';
						'Notes' = '';
						'checkName' = ''
					}
					$tmp += $obj
				}
		}

	# Third loop through the retirements
	$ServiceRetirementMSG = Get-WARAMessage -Message 'ImpactedResources_ServiceRetirement'
	foreach ($Retirement in $Retirements)
		{
			if (![string]::IsNullOrEmpty($Retirement)) {
				$RetirementType = $RootTypes | Where-Object {$_.FriendlyName -eq $Retirement.ImpactedService}
				$RetirementType = if(![string]::IsNullOrEmpty($RetirementType)) { $RetirementType.ResourceType } else { $Retirement.ImpactedService }

				try {
					$HTML = New-Object -Com 'HTMLFile'
					$HTML.write([ref]$Retirement.Description)
					$RetirementDescriptionFull = $Html.body.innerText
					$SplitDescription = $RetirementDescriptionFull.split('Help and support').split('Required action')
				} catch {
					$SplitDescription = ' ', ' '
				}

				$obj = @{
					'REQUIRED ACTIONS / REVIEW STATUS' = $ServiceRetirementMSG;
					'ValidationCategory' = 'Retirements';
					'Resource Type' = $RetirementType;
					'subscriptionId' = $Retirement.Subscription;
					'resourceGroup' = 'RG name not needed';
					'location' = 'Location not needed';
					'name' = 'Get ResourceName from Azure Portal';
					'id' = 'Get ResourceID from Azure Portal';
					'custom1' = 'No data needed';
					'custom2' = 'No data needed';
					'custom3' = 'No data needed';
					'custom4' = 'No data needed';
					'custom5' = 'No data needed';
					'Recommendation Title' = $Retirement.Title;
					'Impact' = 'Medium';
					'Recommendation Control' = '';
					'Potential Benefit' = '';
					'Learn More Link' = '';
					'Long Description' = [string]$SplitDescription[0];
					'Guid' = 'GUID not needed';
					'Category' = '';
					'Source' = 'Azure Service Health - Service Retirements';
					'WAF Pillar' = 'Reliability';
					'Platform Issue TrackingId' = '';
					'Retirement TrackingId' = $Retirement.TrackingId;
					'Support Request Number' = '';
					'Notes' = '';
					'checkName' = ''
				}
				$tmp += $obj
			}
		}

	# Fourth loop through the WAF recommendations
	$WAFMSG = Get-WARAMessage -Message 'ImpactedResources_WAF'
	foreach ($waf in $WAFYAMLContent)
		{
			if (![string]::IsNullOrEmpty($waf))
				{
					$obj = @{
						#'REQUIRED ACTIONS / REVIEW STATUS_x000a_(If the recommendation is applicable then update the cell to "Reviewed")' = $WAFMSG;
						'REQUIRED ACTIONS / REVIEW STATUS' = $WAFMSG;
						'ValidationCategory' = 'WAF';
						'Resource Type' = $waf.recommendationResourceType;
						'subscriptionId' = '';
						'resourceGroup' = '';
						'location' = '';
						'name' = 'Entire Workload';
						'id' = '';
						'custom1' = '';
						'custom2' = '';
						'custom3' = '';
						'custom4' = '';
						'custom5' = '';
						'Recommendation Title' = $waf.description;
						'Impact' = $waf.recommendationImpact;
						'Recommendation Control' = ($waf.recommendationControl -csplit '(?=[A-Z])' -ne '' -join ' ');
						'Potential Benefit' = $waf.potentialBenefits;
						'Learn More Link' = ($Recom.learnMoreLink.url -join " `n");
						'Long Description' = $waf.longDescription;
						'Guid' = $waf.aprlGuid;
						'Category' = 'Well Architected';
						'Source' = '';
						'WAF Pillar' = '';
						'Platform Issue TrackingId' = '';
						'Retirement TrackingId' = '';
						'Support Request Number' = '';
						'Notes' = '';
						'checkName' = ''
					}
					$tmp += $obj
				}
		}

	# Standard Architecture and Reliability Design Patterns Recommendations
	$ArchtectureMSG = Get-WARAMessage -Message 'ImpactedResources_Architecture'
	$obj = @{
		'REQUIRED ACTIONS / REVIEW STATUS' = $ArchtectureMSG;
		'ValidationCategory' = 'Architectural';
		'Resource Type' = 'Microsoft.Subscription/Subscriptions';
		'subscriptionId' = '';
		'resourceGroup' = '';
		'location' = '';
		'name' = '';
		'id' = '';
		'custom1' = '';
		'custom2' = '';
		'custom3' = '';
		'custom4' = '';
		'custom5' = '';
		'Recommendation Title' = '';
		'Impact' = '';
		'Recommendation Control' = '';
		'Potential Benefit' = '';
		'Learn More Link' = '';
		'Long Description' = '';
		'Guid' = '';
		'Category' = '';
		'Source' = '';
		'WAF Pillar' = '';
		'Platform Issue TrackingId' = '';
		'Retirement TrackingId' = '';
		'Support Request Number' = '';
		'Notes' = '';
		'checkName' = ''
	}
	$tmp += $obj

	# Returns the array with all the recommendations already formatted to be exported to Excel
	return $tmp
}

function Export-WARAImpactedResources
{
	Param($ImpactedResourcesFormatted)

	$Style = @()
	$Style += New-ExcelStyle -HorizontalAlignment Left -WrapText -Range A:A
	$Style += New-ExcelStyle -HorizontalAlignment Center -Range A12:A12
	$Style += New-ExcelStyle -HorizontalAlignment Center -Range B:F
	$Style += New-ExcelStyle -HorizontalAlignment Left -Range G:L
	$Style += New-ExcelStyle -HorizontalAlignment Center -Range G12:L12
	$Style += New-ExcelStyle -HorizontalAlignment Center -WrapText -Range M:P
	$Style += New-ExcelStyle -HorizontalAlignment Center -WrapText -Range R:R
	$Style += New-ExcelStyle -HorizontalAlignment Center -Range S:Z
	$Style += New-ExcelStyle -VerticalAlignment Center -Range A:Z

	$ImpactedResourcesSheet = New-Object System.Collections.Generic.List[System.Object]
	$ImpactedResourcesSheet.Add('REQUIRED ACTIONS / REVIEW STATUS')
	$ImpactedResourcesSheet.Add('ValidationCategory')
	$ImpactedResourcesSheet.Add('Resource Type')
	$ImpactedResourcesSheet.Add('subscriptionId')
	$ImpactedResourcesSheet.Add('resourceGroup')
	$ImpactedResourcesSheet.Add('location')
	$ImpactedResourcesSheet.Add('name')
	$ImpactedResourcesSheet.Add('id')
	$ImpactedResourcesSheet.Add('custom1')
	$ImpactedResourcesSheet.Add('custom2')
	$ImpactedResourcesSheet.Add('custom3')
	$ImpactedResourcesSheet.Add('custom4')
	$ImpactedResourcesSheet.Add('custom5')
	$ImpactedResourcesSheet.Add('Recommendation Title')
	$ImpactedResourcesSheet.Add('Impact')
	$ImpactedResourcesSheet.Add('Recommendation Control')
	$ImpactedResourcesSheet.Add('Potential Benefit')
	$ImpactedResourcesSheet.Add('Learn More Link')
	$ImpactedResourcesSheet.Add('Long Description')
	$ImpactedResourcesSheet.Add('Guid')
	$ImpactedResourcesSheet.Add('Category')
	$ImpactedResourcesSheet.Add('Source')
	$ImpactedResourcesSheet.Add('WAF Pillar')
	$ImpactedResourcesSheet.Add('Platform Issue TrackingId')
	$ImpactedResourcesSheet.Add('Retirement TrackingId')
	$ImpactedResourcesSheet.Add('Support Request Number')
	$ImpactedResourcesSheet.Add('Notes')
	$ImpactedResourcesSheet.Add('checkName')

	Write-Debug ((get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Exporting Impacted Resources to Excel')
	$ImpactedResourcesFormatted | ForEach-Object { [PSCustomObject]$_ } | Select-Object $ImpactedResourcesSheet |
		Export-Excel -Path $NewExpertAnalysisFile -WorksheetName $ImpactedResourcesSheetRef -TableName 'impactedresources' -TableStyle $TableStyle -Style $Style -StartRow 12

}

<############################## Analysis Planning #########################################>

function Initialize-WARAAnalysisPlanning
{
	Param(
		[Parameter(mandatory = $true)]
		$InScopeResources
	)

	Write-Debug ((get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Grouping InScope Resources by Resource Type')
	$ResourceTypes = $InScopeResources | Group-Object -Property type

# Formula has to be extracted from the Excel file to be in this specific standard used by Excel, otherwise it will not work
$ImpactedResourcesFormula = @"
=IF(COUNTIF($ImpactedResourcesSheetRef!C:C, TableTypes8[[#This Row],[Resource Type]])=0, 0, COUNTA(_xlfn.UNIQUE(_xlfn._xlws.FILTER($ImpactedResourcesSheetRef!H:H, ($ImpactedResourcesSheetRef!C:C=TableTypes8[[#This Row],[Resource Type]]) * ($ImpactedResourcesSheetRef!H:H<>"Get ResourceID from Azure Portal")))))
"@

$ReviewedFormula = @"
=IF(OR(AND(TableTypes8[[#This Row],[Category]]="Support Requests", COUNTIFS($SupportRequestsSheetRef!A:A, "<>Reviewed")=0),AND(TableTypes8[[#This Row],[Category]]="Platform Issues", COUNTIFS($PlatformIssuesSheetRef!A:A,
"<>Reviewed")=0),AND(TableTypes8[[#This Row],[Category]]="Impacted Resources", COUNTIFS($ImpactedResourcesSheetRef!A:A, "<>Reviewed", $ImpactedResourcesSheetRef!C:C, TableTypes8[[#This Row],[Resource Type]], $ImpactedResourcesSheetRef!O:O,        
"<>Low")=0)), "Reviewed", "Pending")
"@ 

	$tmp = @()
	$Counter = 11
	foreach ($ResourceType in $ResourceTypes)
		{
			$RootType = ""
			$RootType = $RootTypes | Where-Object {$_.ResourceType -eq $ResourceType.Name}
			$APRLOrAdv = if($RootType.WARAinScope -eq 'yes' -and $RootType.InAprlAndOrAdvisor -eq 'yes') { 'Yes' } else { 'No' }
			$obj = @{
				'Category'		 	 											= 'Impacted Resources';
				'Resource Type' 	 											= $ResourceType.Name;
				'Number of Resources'											= $ResourceType.'Count';
				'Impacted Resources' 											= $ImpactedResourcesFormula;
				'Has Recommendations_x000a_in APRL/Advisor'				 		= $APRLOrAdv;
				'Assessment Status'												= $ReviewedFormula;
			}
			$Counter ++
			$tmp += $obj
		}

	$obj = @{
		'Category'		 	 											= 'Support Requests';
		'Resource Type' 	 											= 'N/A';
		'Number of Resources'											= 'n/a';
		'Impacted Resources' 											= 'n/a';
		'Has Recommendations_x000a_in APRL/Advisor'						= 'Yes';
		'Assessment Status'												= 'Pending';
	}
	$tmp += $obj

	$obj = @{
		'Category'		 	 											= 'Platform Issues';
		'Resource Type'											 	 	= 'N/A';
		'Number of Resources'											= 'n/a';
		'Impacted Resources' 											= 'n/a';
		'Has Recommendations_x000a_in APRL/Advisor'						= 'Yes';
		'Assessment Status'												= 'Pending';
	}
	$tmp += $obj

	return $tmp

}

function Export-WARAAnalysisPlanning
{
	Param($AnalysisPlanningFormatted)

	$Style = @()
	$Style += New-ExcelStyle -HorizontalAlignment Center -Range A:H
	$Style = @()
	$Style += New-ExcelStyle -HorizontalAlignment Center -Range A:H


	$AnalysesPlanning = New-Object System.Collections.Generic.List[System.Object]
	$AnalysesPlanning.Add('Category')
	$AnalysesPlanning.Add('Resource Type')
	$AnalysesPlanning.Add('Number of Resources')
	$AnalysesPlanning.Add('Impacted Resources')
	$AnalysesPlanning.Add('Has Recommendations_x000a_in APRL/Advisor')
	$AnalysesPlanning.Add('Assessment Owner')
	$AnalysesPlanning.Add('Assessment Status')
	$AnalysesPlanning.Add('Notes')


	Write-Debug ((get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Exporting Analysis Planning to Excel')
	$AnalysisPlanningFormatted | ForEach-Object { [PSCustomObject]$_ } | Select-Object $AnalysesPlanning |
		Export-Excel -Path $NewExpertAnalysisFile -WorksheetName $AnalysisPlanningSheetRef -TableName 'TableTypes8' -TableStyle $TableStyle -Style $Style -StartRow 10
}

<############################## Platform Issues #########################################>

function Initialize-WARAPlatformIssues 
{
	Param(
		[Parameter(mandatory = $true)]
		$PlatformIssues
	)

	$OutagesMSG = Get-WARAMessage -Message 'PlatformIssues_Standard'

	Write-Debug ((get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Formatting Platform Issues')
	# Just getting a sum of the total outages that will be included in the Excel file, in case there are no outages, a row will be added with empty values later
	$TotalOutages = ($PlatformIssues | Where-Object {$_.properties.description -like '*How can customers make incidents like this less impactful?*'}).count

	$tmp = @()
	foreach ($Outage in $PlatformIssues)
		{
			if ($Outage.properties.description -like '*How can customers make incidents like this less impactful?*') {
				try {
					$HTML = New-Object -Com 'HTMLFile'
					$HTML.write([ref]$Outage.properties.description)
					$OutageDescription = $Html.body.innerText
					$SplitDescription = $OutageDescription.split('How can we make our incident communications more useful?').split('How can customers make incidents like this less impactful?').split('How are we making incidents like this less likely or less impactful?').split('How did we respond?').split('What went wrong and why?').split('What happened?')
					$whathap = ($SplitDescription[1]).Split([Environment]::NewLine)[1]
					$whatwent = ($SplitDescription[2]).Split([Environment]::NewLine)[1]
					$howdid = ($SplitDescription[3]).Split([Environment]::NewLine)[1]
					$howarewe = ($SplitDescription[4]).Split([Environment]::NewLine)[1]
					$howcan = ($SplitDescription[5]).Split([Environment]::NewLine)[1]
				}
				catch {
					$whathap = ""
					$whatwent = ""
					$howdid = ""
					$howarewe = ""
					$howcan = ""
				}

				$ImpactedSvc = if ($Outage.properties.impact.impactedService.count -gt 1) { $Outage.properties.impact.impactedService | ForEach-Object { $_ + ' ,' } }else { $Outage.properties.impact.impactedService}
				$ImpactedSvc = [string]$ImpactedSvc
				$ImpactedSvc = if ($ImpactedSvc -like '* ,*') { $ImpactedSvc -replace ".$" }else { $ImpactedSvc }

				$obj = @{
					'REQUIRED ACTIONS / REVIEW STATUS'	 									= $OutagesMSG;
					'Tracking ID' 															= $Outage.name;
					'Event Type' 															= $Outage.properties.eventType;
					'Event Source' 															= $Outage.properties.eventSource;
					'Status' 																= $Outage.properties.status;
					'Title' 																= $Outage.properties.title
					'Level' 																= $Outage.properties.level;
					'Event Level' 															= $Outage.properties.eventLevel;
					'Start Time' 															= $Outage.properties.impactStartTime;
					'Mitigation Time'														= $Outage.properties.impactMitigationTime;
					'Impacted Service'														= $ImpactedSvc;
					'What happened' 														= $whathap;
					'What went wrong and why' 												= $whatwent;
					'How did we respond' 													= $howdid;
					'How are we making incidents like this less likely or less impactful' 	= $howarewe;
					'How can customers make incidents like this less impactful' 			= $howcan;
				}
				$tmp += $obj
			}
		}

	# If there are no outages, a row will be added with empty values
	if ($TotalOutages -eq 0) {
		$obj = @{
			'REQUIRED ACTIONS / REVIEW STATUS' 										= $OutagesMSG;
			'Tracking ID' 															= '';
			'Event Type' 															= '';
			'Event Source' 															= '';
			'Status' 																= '';
			'Title' 																= '';
			'Level' 																= '';
			'Event Level' 															= '';
			'Start Time' 															= '';
			'Mitigation Time'														= '';
			'Impacted Service'														= '';
			'What happened' 														= '';
			'What went wrong and why' 												= '';
			'How did we respond' 													= '';
			'How are we making incidents like this less likely or less impactful' 	= '';
			'How can customers make incidents like this less impactful' 			= '';
		}
		$tmp += $obj
	}

	return $tmp
}

function Export-WARAPlatformIssues
{
	Param($PlatformIssuesFormatted)

	$Style = @()
	$Style += New-ExcelStyle -HorizontalAlignment Left -WrapText -Range A:A
	$Style += New-ExcelStyle -HorizontalAlignment Center -Range A12:A12
	$Style += New-ExcelStyle -HorizontalAlignment Center -Range B:K
	$Style += New-ExcelStyle -HorizontalAlignment Center -WrapText -Range L:P
	$Style += New-ExcelStyle -VerticalAlignment Center -Range B:P


	$PlatformIssuesSheet = New-Object System.Collections.Generic.List[System.Object]
	$PlatformIssuesSheet.Add('REQUIRED ACTIONS / REVIEW STATUS')
	$PlatformIssuesSheet.Add('Tracking ID')
	$PlatformIssuesSheet.Add('Event Type')
	$PlatformIssuesSheet.Add('Event Source')
	$PlatformIssuesSheet.Add('Status')
	$PlatformIssuesSheet.Add('Title')
	$PlatformIssuesSheet.Add('Level')
	$PlatformIssuesSheet.Add('Event Level')
	$PlatformIssuesSheet.Add('Start Time')
	$PlatformIssuesSheet.Add('Mitigation Time')
	$PlatformIssuesSheet.Add('Impacted Service')
	$PlatformIssuesSheet.Add('What happened')
	$PlatformIssuesSheet.Add('What went wrong and why')
	$PlatformIssuesSheet.Add('How did we respond')
	$PlatformIssuesSheet.Add('How are we making incidents like this less likely or less impactful')
	$PlatformIssuesSheet.Add('How can customers make incidents like this less impactful')

	Write-Debug ((get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Exporting Platform Issues to Excel')
	$PlatformIssuesFormatted | ForEach-Object { [PSCustomObject]$_ } | Select-Object $PlatformIssuesSheet |
		Export-Excel -Path $NewExpertAnalysisFile -WorksheetName $PlatformIssuesSheetRef -TableName 'platformIssues' -TableStyle $TableStyle -Style $Style -StartRow 12

}

<############################## Support Requests #########################################>

function Initialize-WARASupportTicket
{
	Param(
		[Parameter(mandatory = $true)]
		$SupportTickets
	)

	$SupportTicketsMSG = Get-WARAMessage -Message 'SupportTickets_Standard'

	Write-Debug ((get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Formatting Support Tickets')
	# Just getting a sum of the total support tickets that will be included in the Excel file, in case there are no support tickets, a row will be added with empty values later
	$TotalSupportTickets = ($SupportTickets | Where-Object {![string]::IsNullOrEmpty($_.title)}).count

	$tmp = @()
	foreach ($Ticket in $SupportTickets)
		{
			if (![string]::IsNullOrEmpty($Ticket.title)) {
				$obj = @{
					'REQUIRED ACTIONS / REVIEW STATUS' 			= $SupportTicketsMSG;
					'Ticket ID' 								= $Ticket.'Ticket ID';
					'Severity' 									= $Ticket.Severity;
					'Status' 									= $Ticket.Status;
					'Support Plan Type' 						= $Ticket.'Support Plan Type';
					'Creation Date' 							= $Ticket.'Creation Date';
					'Modified Date' 							= $Ticket.'Modified Date';
					'Title' 									= $Ticket.Title;
					'Related Resource' 							= $Ticket.'Related Resource'
				}
				$tmp += $obj
			}
		}

	# If there are no support tickets, a row will be added with empty values
	if ($TotalSupportTickets -eq 0) {
		$obj = @{
			'REQUIRED ACTIONS / REVIEW STATUS'	 		= $SupportTicketsMSG;
			'Ticket ID' 								= '';
			'Severity' 									= '';
			'Status' 									= '';
			'Support Plan Type' 						= '';
			'Creation Date' 							= '';
			'Modified Date' 							= '';
			'Title' 									= '';
			'Related Resource' 							= ''
		}
		$tmp += $obj
	}

	return $tmp

}

function Export-WARASupportTicket
{
	Param($SupportTicketsFormatted)

	$Style = @()
	$Style += New-ExcelStyle -HorizontalAlignment Left -WrapText -Range A:A
	$Style += New-ExcelStyle -HorizontalAlignment Center -Range A12:A12
	$Style += New-ExcelStyle -HorizontalAlignment Center -Range B:I
	$Style += New-ExcelStyle -VerticalAlignment Center -Range B:I



	$SupportTicketsSheet = New-Object System.Collections.Generic.List[System.Object]
	$SupportTicketsSheet.Add('REQUIRED ACTIONS / REVIEW STATUS')
	$SupportTicketsSheet.Add('Ticket ID')
	$SupportTicketsSheet.Add('Severity')
	$SupportTicketsSheet.Add('Status')
	$SupportTicketsSheet.Add('Support Plan Type')
	$SupportTicketsSheet.Add('Creation Date')
	$SupportTicketsSheet.Add('Modified Date')
	$SupportTicketsSheet.Add('Title')
	$SupportTicketsSheet.Add('Related Resource')


	Write-Debug ((get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Exporting Support Tickets to Excel')
	$SupportTicketsFormatted | ForEach-Object { [PSCustomObject]$_ } | Select-Object $SupportTicketsSheet |
		Export-Excel -Path $NewExpertAnalysisFile -WorksheetName $SupportRequestsSheetRef -TableName 'supportRequests' -TableStyle $TableStyle -Style $Style -StartRow 12 -NoNumberConversion "Ticket ID"
}

<############################## Workload Inventory #########################################>

function Initialize-WARAWorkloadInventory
{
	Param(
		[Parameter(mandatory = $true)]
		$InScopeResources
	)

	# Just getting a sum of the total in scope resources that will be included in the Excel file, in case there are no in scope resources, a row will be added with empty values later
	$TotalInScope = ($InScopeResources | Where-Object {![string]::IsNullOrEmpty($_.id)}).count

	Write-Debug ((get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Formatting Workload Inventory')

	$tmp = @()
	foreach ($resource in $InScopeResources)
		{
			if (![string]::IsNullOrEmpty($resource.id)) {
				$obj = @{
					'subscriptionId' 	= $resource.subscriptionId;
					'resourceGroup' 	= $resource.resourceGroup;
					'type' 				= $resource.type
					'location' 			= $resource.location;
					'name' 				= $resource.name;
					'id' 				= $resource.id;
					'tenantId' 			= $resource.tenantId;
					'kind'				= $resource.kind;
					'managedBy'			= $resource.managedBy;
					'sku'				= [string]$resource.sku;
					'plan'				= $resource.plan;
					'zones'				= [string]$resource.zones
				}
				$tmp += $obj
			}
		}

	if ($TotalInScope -eq 0) {
		$obj = @{
			'subscriptionId' 	= '';
			'resourceGroup' 	= '';
			'type' 				= '';
			'location' 			= '';
			'name' 				= '';
			'id' 				= '';
			'tenantId' 			= '';
			'kind'				= '';
			'managedBy'			= '';
			'sku'				= '';
			'plan'				= '';
			'zones'				= ''
		}
		$tmp += $obj
	}

	return $tmp
}

function Export-WARAWorkloadInventory
{
	Param($WorkloadInventoryFormatted)

	$Style = @()
	$Style += New-ExcelStyle -HorizontalAlignment Center


	$InScopeSheet = New-Object System.Collections.Generic.List[System.Object]
	$InScopeSheet.Add('id')
	$InScopeSheet.Add('name')
	$InScopeSheet.Add('type')
	$InScopeSheet.Add('tenantId')
	$InScopeSheet.Add('kind')
	$InScopeSheet.Add('location')
	$InScopeSheet.Add('resourceGroup')
	$InScopeSheet.Add('subscriptionId')
	$InScopeSheet.Add('managedBy')
	$InScopeSheet.Add('sku')
	$InScopeSheet.Add('plan')
	$InScopeSheet.Add('zones')

	Write-Debug ((get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Exporting Workload Inventory to Excel')
	$WorkloadInventoryFormatted | ForEach-Object { [PSCustomObject]$_ } | Select-Object $InScopeSheet |
		Export-Excel -Path $NewExpertAnalysisFile -WorksheetName $WorkloadInventorySheetRef -TableName 'InScopeResources' -TableStyle $TableStyle -Style $Style -StartRow 12
}

<############################## Extra Configurations #########################################>

function Set-ExpertAnalysisFile
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory = $true)]
		[string]$NewExpertAnalysisFile
	)

	Write-Debug ((get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Openning Excel File for Last Customization')
	$Excel = Open-ExcelPackage -path $NewExpertAnalysisFile

	$sheet = $Excel.Workbook.Worksheets[$ImpactedResourcesSheetRef]

	Write-Debug ((get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Adding Conditional Formatting to Impacted Resources Sheet')

	Add-ConditionalFormatting -WorkSheet $sheet -RuleType ContainsText -ConditionValue "REQUIRED ACTIONS: Azure Service Health - Service Retirements" -Address A:A -BackgroundColor ([System.Drawing.Color]::fromArgb(0xd87406))
	Add-ConditionalFormatting -WorkSheet $sheet -RuleType ContainsText -ConditionValue "REQUIRED ACTIONS: Azure Service Health - Platform Issues" -Address A:A -BackgroundColor ([System.Drawing.Color]::fromArgb(0xee9432))
	Add-ConditionalFormatting -WorkSheet $sheet -RuleType ContainsText -ConditionValue "REQUIRED ACTIONS: Well-Architected Framework" -Address A:A -BackgroundColor ([System.Drawing.Color]::fromArgb(0xfbe757))
	Add-ConditionalFormatting -WorkSheet $sheet -RuleType ContainsText -ConditionValue "REQUIRED ACTIONS: ResourceType not available in APRL/Advisor" -Address A:A -BackgroundColor ([System.Drawing.Color]::fromArgb(0xfa7a06))
	Add-ConditionalFormatting -WorkSheet $sheet -RuleType ContainsText -ConditionValue "REQUIRED ACTIONS: Recommendation does not have automated validation." -Address A:A -BackgroundColor ([System.Drawing.Color]::fromArgb(0xffa500))
	Add-ConditionalFormatting -WorkSheet $sheet -RuleType ContainsText -ConditionValue "REQUIRED ACTIONS: Architectural and Reliability Design Patterns Recommendations" -Address A:A -BackgroundColor ([System.Drawing.Color]::fromArgb(0x92d050))

	$sheet = $Excel.Workbook.Worksheets[$PlatformIssuesSheetRef]

	Write-Debug ((get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Adding Conditional Formatting to Platform Issues Sheet')

	Add-ConditionalFormatting -WorkSheet $sheet -RuleType ContainsText -ConditionValue "REQUIRED ACTIONS: Review Platform Issue and create recommendations" -Address A:A -BackgroundColor ([System.Drawing.Color]::fromArgb(0xee9432))

	$sheet = $Excel.Workbook.Worksheets[$SupportRequestsSheetRef]

	Write-Debug ((get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Adding Conditional Formatting to Support Requests Sheet')

	Add-ConditionalFormatting -WorkSheet $sheet -RuleType ContainsText -ConditionValue "REQUIRED ACTIONS: Review Customer Support Requests and create recommendations" -Address A:A -BackgroundColor ([System.Drawing.Color]::fromArgb(0xFA7A06))

	Write-Debug ((get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Closing Excel File')
	Close-ExcelPackage -ExcelPackage $Excel -Calculate
}


# Excel Sheet Reference

$ImpactedResourcesSheetRef = '4.ImpactedResourcesAnalysis'
$AnalysisPlanningSheetRef = '3.AnalysisPlanning'
$PlatformIssuesSheetRef = '5.PlatformIssuesAnalysis'
$SupportRequestsSheetRef = '6.SupportRequestsAnalysis'
$WorkloadInventorySheetRef = '2.WorkloadInventory'

Write-Debug (' ---------------------------------- STARTING DATA ANALYZER SCRIPT --------------------------------------- ')
#Call the functions
$Version = '2.2.0'
Write-Host 'Version: ' -NoNewline
Write-Host $Version -ForegroundColor DarkBlue

Write-Host "Starting the " -NoNewline
Write-Host "WARA Analyzer" -ForegroundColor Magenta

Write-Debug ((get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Invoking Function: Read-JSONFile')
Test-Requirement

Write-Debug ((get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Invoking Function: Read-JSONFile')
$JSONContent = Read-JSONFile -JSONFile $JSONFile

Write-Debug ((get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Invoking Function: Copy-RepositoryFiles')
# Setting the ClonePath to the path where the repository files were cloned
$clonePath = Copy-RepositoryFiles -RepoUrl $RepositoryUrl
Write-Debug ((get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - ClonePath: ' + $clonePath)

# Checking if the JSON file was created by the current version of the Collector Script
if ($JSONContent.ScriptDetails.Version -eq (Get-Content -Path "$ClonePath\tools\Version.json" -ErrorAction SilentlyContinue | ConvertFrom-Json).Collector) {
	Write-Host 'The JSON file was created by the current version of the Collector Script. ' -BackgroundColor DarkGreen -NoNewline
	Write-Host ''
} else {
	Write-Host "The JSON file was created by an outdated version ($($JSONContent.ScriptDetails.Version)) of the Collector Script. The latest version is $((Get-Content -Path "$ClonePath\tools\Version.json" -ErrorAction SilentlyContinue | ConvertFrom-Json).Collector)" -BackgroundColor DarkRed -NoNewline
	Write-Host ''
}

Write-Debug ((get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Importing Supported Types')
# Importing the CSV files to get the supported types and the friendly names for the resource types in the Retirements
$RootTypes = Get-Content -Path "$clonePath/tools/WARAinScopeResTypes.csv" | ConvertFrom-Csv
$RootTypes = $RootTypes | Where-Object {$_.InAprlAndOrAdvisor -eq 'yes'}

Write-Host 'Analysing Excel File Template: ' -NoNewline
Write-Host $ExpertAnalysisFile -ForegroundColor Blue

$NewExpertAnalysisFile = Save-WARAExcelFile -ExpertAnalysisFile $ExpertAnalysisFile

Write-Debug ((get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Invoking Function: Initialize-WARAImpactedResources')
# Creating the Array with the Impacted Resources to be added to the Excel file
$ImpactedResources 	= Initialize-WARAImpactedResources -ImpactedResources $JSONContent.ImpactedResources -Advisory $JSONContent.Advisory -Retirements $JSONContent.Retirements -ScriptDetails $JSONContent.ScriptDetails

Write-Host $ImpactedResourcesSheetRef -NoNewline -ForegroundColor Green
Write-Host ': ' -NoNewline
$ImpactResCount = $ImpactedResources | Measure-Object
Write-Host ([string]$ImpactResCount.count) -NoNewline -ForegroundColor Cyan
Write-Host ' (Lines to be added to the new Excel file)'

Write-Debug ((get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Invoking Function: Export-WARAImpactedResources')
# Adding the Impacted Resources to the Excel file
Export-WARAImpactedResources -ImpactedResourcesFormatted $ImpactedResources

Write-Debug ((get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Invoking Function: Initialize-WARAPlatformIssues')
# Creating the Array with the Platform Issues to be added to the Excel file
$PlatformIssues 	= Initialize-WARAPlatformIssues -PlatformIssues $JSONContent.Outages

Write-Host $PlatformIssuesSheetRef -NoNewline -ForegroundColor Green
Write-Host ': ' -NoNewline
$PlatissuesCount = $PlatformIssues | Measure-Object
Write-Host ([string]$PlatissuesCount.Count) -NoNewline -ForegroundColor Cyan
Write-Host ' (Lines to be added to the new Excel file)'

Write-Debug ((get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Invoking Function: Export-WaraPlatformIssues')
# Adding the Platform Issues to the Excel file
Export-WARAPlatformIssues -PlatformIssuesFormatted $PlatformIssues

Write-Debug ((get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Invoking Function: Initialize-WARASupportTicket')
# Creating the Array with the Support Tickets to be added to the Excel file
$SupportTickets 	= Initialize-WARASupportTicket -SupportTickets $JSONContent.SupportTickets

Write-Host $SupportRequestsSheetRef -NoNewline -ForegroundColor Green
Write-Host ': ' -NoNewline
$SuppTicketsCount = $SupportTickets | Measure-Object
Write-Host ([string]$SuppTicketsCount.count) -NoNewline -ForegroundColor Cyan
Write-Host ' (Lines to be added to the new Excel file)'

Write-Debug ((get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Invoking Function: Export-WaraSupportTicket')
# Adding the Support Tickets to the Excel file
Export-WARASupportTicket -SupportTicketsFormatted $SupportTickets

Write-Debug ((get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Invoking Function: Initialize-WARAAnalysisPlanning')
# Creating the Array with the Analysis Planning to be added to the Excel file
$AnalysisPlanning 	= Initialize-WARAAnalysisPlanning -InScopeResources $JSONContent.resourceInventory

Write-Host $AnalysisPlanningSheetRef -NoNewline -ForegroundColor Green
Write-Host ': ' -NoNewline
$AnalysisPlanningCount = $AnalysisPlanning | Measure-Object
Write-Host ([string]$AnalysisPlanningCount.count) -NoNewline -ForegroundColor Cyan
Write-Host ' (Lines to be added to the new Excel file)'

Write-Debug ((get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Invoking Function: Export-WaraAnalysisPlanning')
# Adding the Analysis Planning to the Excel file
Export-WARAAnalysisPlanning -AnalysisPlanningFormatted $AnalysisPlanning

Write-Debug ((get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Invoking Function: Initialize-WARAWorkloadInventory')
# Creating the Array with the Workload Inventory to be added to the Excel file
$WorkloadInventory 	= Initialize-WARAWorkloadInventory -InScopeResources $JSONContent.resourceInventory

Write-Host $WorkloadInventorySheetRef -NoNewline -ForegroundColor Green
Write-Host ': ' -NoNewline
$WorkloadInvCount = $WorkloadInventory | Measure-Object
Write-Host ([string]$WorkloadInvCount.count) -NoNewline -ForegroundColor Cyan
Write-Host ' (Lines to be added to the new Excel file)'

# Adding the Workload Inventory to the Excel file
Write-Debug ((get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Invoking Function: Export-WaraWorkloadInventory')
Export-WARAWorkloadInventory -WorkloadInventoryFormatted $WorkloadInventory

Write-Host 'Overall Excel File' -NoNewline -ForegroundColor Green
Write-Host ': ' -NoNewline
Write-Host 'Extra Excel Customization' -ForegroundColor Cyan

# Setting the Excel file with the extra configurations like the conditional formatting
Write-Debug ((get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Invoking Function: Set-ExpertAnalysisFile')
Set-ExpertAnalysisFile -NewExpertAnalysisFile $NewExpertAnalysisFile

}
$TotalTime = $Runtime.Totalminutes.ToString('#######.##')

Write-Host '---------------------------------------------------------------------'
Write-Host ('Execution Complete. Total Runtime was: ') -NoNewline
Write-Host $TotalTime -NoNewline -ForegroundColor Cyan
Write-Host (' Minutes')
Write-Host 'Excel File: ' -NoNewline
Write-Host $NewExpertAnalysisFile -ForegroundColor Blue
Write-Host '---------------------------------------------------------------------'
