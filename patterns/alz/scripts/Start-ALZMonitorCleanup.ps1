<#
.SYNOPSIS
    This script cleans up the resources deployed by the ALZ-Monitor automation, including alerts, policy assignments, policy definitions, and policy assignment role assignments.
.DESCRIPTION

.NOTES
    In order for this script to function the deployed resources must have a tag _deployed_by_alz_monitor with a value of true and Policy resources must have metadata property
    named _deployed_by_alz_monitor with a value of True. These tags and metadata are included in the automation, but if they are subsequently removed, there may be orphaned
    resources after this script executes.

    The Role Assignments associated with Policy assignment identities and including _deployed_by_alz_monitor in the description field will also be deleted.

    This script leverages the Azure Resource Graph to find object to delete. Note that the Resource Graph lags behind ARM by a couple minutes.
.LINK
    https://github.com/Azure/alz-monitor

.EXAMPLE
    ./Start-ALZMonitorCleanup.ps1 -ReportOnly
    # generate a list of the resource IDs which would be deleted by this script

.EXAMPLE
    ./Start-ALZMonitorCleanup.ps1 -WhatIf
    # show output of what would happen if deletes executed

.EXAMPLE
    ./Start-ALZMonitorCleanup.ps1 -Force
    # delete all resources deployed by the ALZ-Monitor IaC without prompting for confirmation
#>

[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    # output a list of the resources to be deleted
    [switch]$reportOnly,
    # if not specified, delete will prompt for confirmation
    [switch]$force
)

Function Search-AzGraphRecursive {
    # ensure query results with more than 100 resources and/or over more than 10 management groups are returned
    param($query, $managementGroupNames, $skipToken)

    $optionalParams = @{}
    If ($skipToken) {
        $optionalParams += @{skipToken = $skipToken }
    }

    # ARG will only query 10 management groups at a time--implement batching
    If ($managementGroupNames.count -gt 10) {
        $managementGroupBatches = @()

        For ($i=0;$i -le $managementGroupNames.count;$i=$i+10) {
            $batchGroups = $managementGroupNames[$i..($i+9)]
            $managementGroupBatches += ,@($batchGroups)

            If ($batchGroups.count -lt 10) {
                continue
            }
        }

        $result = @()
        ForEach ($managementGroupBatch in $managementGroupBatches) {
            $batchResult = Search-AzGraph -Query $query -ManagementGroup $managementGroupBatch -Verbose:$false @optionalParams

            # resource graph returns pages of 100 resources, if there are more than 100 resources in a batch, recursively query for more
            If ($batchResult.count -eq 100 -and $batchResult.SkipToken) {
                $result += $batchResult
                Search-AzGraphRecursive -query $query -managementGroupNames $managementGroupNames -skipToken $batchResult.SkipToken
            }
            else {
                $result += $batchResult
            }
        }
    }
    Else {
        $result = Search-AzGraph -Query $query -ManagementGroup $managementGroupNames -Verbose:$false @optionalParams

        If ($result.count -eq 100 -and $result.SkipToken) {
            Search-AzGraphRecursive -query $query -managementGroupNames $managementGroupNames -skipToken $result.SkipToken
        }
    }

    $result
}

$ErrorActionPreference = 'Stop'

If (-NOT(Get-Module -ListAvailable Az.ResourceGraph)) {
    Write-Warning "This script requires the Az.ResourceGraph module."

    $response = Read-Host "Would you like to install the 'Az.ResourceGraph' module now? (y/n)"
    If ($response -match '[yY]') { Install-Module Az.ResourceGraph -Scope CurrentUser }
}

# get all management groups -- used in graph query scope
$managementGroups = Get-AzManagementGroup
Write-Host "Found '$($managementGroups.Count)' management groups to query for ALZ-Monitor resources."

If ($managementGroups.count -eq 0) {
    Write-Error "The command 'Get-AzManagementGroups' returned '0' groups. This script needs to run with Owner permissions on the Azure Landing Zones intermediate root management group to effectively clean up Policies and all related resources."
}

# get alert resources to delete
$query = "Resources | where type in~ ('Microsoft.Insights/metricAlerts','Microsoft.Insights/activityLogAlerts', 'Microsoft.Insights/scheduledQueryRules') and tags['_deployed_by_alz_monitor'] =~ 'True' | project id"
$alertResourceIds = Search-AzGraphRecursive -Query $query -ManagementGroupNames $managementGroups.Name | Select-Object -ExpandProperty Id | Sort-Object | Get-Unique
Write-Host "Found '$($alertResourceIds.Count)' metric, activity log and log alerts with tag '_deployed_by_alz_monitor=True' to be deleted."

# get resource group to delete
$query = "ResourceContainers | where type =~ 'microsoft.resources/subscriptions/resourcegroups' and tags['_deployed_by_alz_monitor'] =~ 'True' | project id"
$resourceGroupIds = Search-AzGraphRecursive -Query $query -ManagementGroupNames $managementGroups.Name | Select-Object -ExpandProperty Id | Sort-Object | Get-Unique
Write-Host "Found '$($resourceGroupIds.Count)' resource groups with tag '_deployed_by_alz_monitor=True' to be deleted."

# get policy assignments to delete
$query = "policyresources | where type =~ 'microsoft.authorization/policyAssignments' | project name,metadata=parse_json(properties.metadata),type,identity,id | where metadata._deployed_by_alz_monitor =~ 'true'"
$policyAssignmentIds = Search-AzGraphRecursive -Query $query -ManagementGroupNames $managementGroups.Name | Select-Object -ExpandProperty Id | Sort-Object | Get-Unique
Write-Host "Found '$($policyAssignmentIds.Count)' policy assignments with metadata '_deployed_by_alz_monitor=True' to be deleted."

# get policy set definitions to delete
$query = "policyresources | where type =~ 'microsoft.authorization/policysetdefinitions' | project name,metadata=parse_json(properties.metadata),type,id | where metadata._deployed_by_alz_monitor =~ 'true' | project id"
$policySetDefinitionIds = Search-AzGraphRecursive -Query $query -ManagementGroupNames $managementGroups.Name | Select-Object -ExpandProperty Id | Sort-Object | Get-Unique
Write-Host "Found '$($policySetDefinitionIds.Count)' policy set definitions with metadata '_deployed_by_alz_monitor=True' to be deleted."

# get policy definitions to delete
$query = "policyresources | where type =~ 'microsoft.authorization/policyDefinitions' | project name,metadata=parse_json(properties.metadata),type,id | where metadata._deployed_by_alz_monitor =~ 'true' | project id"
$policyDefinitionIds = Search-AzGraphRecursive -Query $query -ManagementGroupNames $managementGroups.Name | Select-Object -ExpandProperty Id | Sort-Object | Get-Unique
Write-Host "Found '$($policyDefinitionIds.Count)' policy definitions with metadata '_deployed_by_alz_monitor=True' to be deleted."

# get role assignments to delete
$query = "authorizationresources | where type =~ 'microsoft.authorization/roleassignments' and properties.description == '_deployed_by_alz_monitor' | project roleDefinitionId = properties.roleDefinitionId, objectId = properties.principalId, scope = properties.scope, id"
$roleAssignments = Search-AzGraphRecursive -Query $query -ManagementGroupNames $managementGroups.Name | Sort-Object -Property id | Get-Unique -AsString
Write-Host "Found '$($roleAssignments.Count)' role assignment with description '_deployed_by_alz_monitor' to be deleted."

If (!$reportOnly.IsPresent) {

    Write-Warning "This script will delete the resources discovered above."

    If (!$force.IsPresent) {
        While ($prompt -notmatch '[yYnN]') {
            $prompt = Read-Host -Prompt 'Would you like to proceed with the deletion? (y/n)'
        }
        If ($prompt -match '[yY]') {
            $force = $true
        }
        Else {
            Write-Host "Exiting script..."
            return
        }
    }

    # delete alert resources
    Write-Host "Deleting alert resources..."
    $alertResourceIds | Foreach-Object { Remove-AzResource -ResourceId $_ -Force:$force -Confirm:(!$force) }

    # delete resource groups
    Write-Host "Deleting resource groups..."
    $resourceGroupIds | ForEach-Object { Remove-AzResourceGroup -ResourceGroupId $_ -Force:$force -Confirm:(!$force) | Out-Null }

    # delete policy assignments
    Write-Host "Deleting policy assignments..."
    $policyAssignmentIds | ForEach-Object { Remove-AzPolicyAssignment -Id $_ -Confirm:(!$force) -ErrorAction Stop }

    # delete policy set definitions
    Write-Host "Deleting policy set definitions..."
    $policySetDefinitionIds | ForEach-Object { Remove-AzPolicySetDefinition -Id $_ -Force:$force -Confirm:(!$force) }

    # delete policy definitions
    Write-Host "Deleting policy definitions..."
    $policyDefinitionIds | ForEach-Object { Remove-AzPolicyDefinition -Id $_ -Force:$force -Confirm:(!$force) }

    # delete policy assignment role assignments
    Write-Host "Deleting role assignments..."
    $roleAssignments | Select-Object -Property objectId,roleDefinitionId,scope | ForEach-Object { Remove-AzRoleAssignment @psItem -Confirm:(!$force) | Out-Null }

    Write-Host "Cleanup complete."
}
Else {
    $resourceToBeDeleted = $alertResourceIds + $resourceGroupIds + $policyAssignmentIds + $policySetDefinitionIds + $policyDefinitionIds + $roleAssignments.Id

    return $resourceToBeDeleted
}
