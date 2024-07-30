<#
.SYNOPSIS
Connects to Azure using the specified tenant ID, scopes, and Azure environment.

.DESCRIPTION
The Connect-ToAzure function connects to Azure using the specified tenant ID, scopes, and Azure environment. It checks if the user is already logged in to a tenant with one of the specified subscriptions. If not, it authenticates the user to Azure using the first valid subscription ID.

.PARAMETER TenantID
The ID of the Azure tenant to connect to. This parameter is mandatory.

.PARAMETER Scopes
An array of scopes representing the subscriptions to check. This parameter is mandatory.

.PARAMETER AzureEnvironment
The Azure environment to connect to. This parameter is mandatory.

.EXAMPLE
Connect-ToAzure -TenantID "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" -Scopes @("/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx", "/subscriptions/yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy","/subscriptions/yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy/resourceGroups/yyyyyyyyy") -AzureEnvironment "AzureCloud"
Connects to Azure using the specified tenant ID and scopes, and the AzureCloud environment.

.NOTES
This function requires the Az module to be installed. Make sure you have the latest version of the Az module installed before using this function.
#>

param (
  [Parameter(Mandatory = $true)]
  [ValidatePattern('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')]
  [string]$TenantID,

  [Parameter(Mandatory = $true)]
  [ValidateScript({
      foreach ($item in $_) {
        if ($item -notmatch '^/subscriptions/([0-9a-fA-F-]{36})(/.*)?$') {
          throw "Invalid scope: $item. Each scope must start with '/subscriptions/' and be followed by a valid subscription ID.`n"
        }
      }
      $true
    })]
  [array]$Scopes,

  [Parameter(Mandatory = $false)]
  [ValidateSet('AzureUSGovernment', 'AzureChinaCloud', 'AzureCloud')]
  [string]$AzureEnvironment = 'AzureCloud'
)

begin {
  try {
    Write-Debug "Begin: Extracting subscription IDs from scopes.`n"
    $SubscriptionIdsToCheck = $Scopes | ForEach-Object {
      if ($_ -match '/subscriptions/([0-9a-fA-F-]{36})') {
        $matches[1]
        Write-Debug $Matches[1]
      }
    }

    Write-Debug "Begin: Retrieving current tenant ID.`n"
    $CurrentTenantId = (Get-AzContext -ErrorAction SilentlyContinue).Tenant.Id

    $LoggedInState = $false
    if ($CurrentTenantId) {
      Write-Debug "Begin: Retrieving all subscriptions for the current tenant.`n"
      $AllSubscriptions = Get-AzSubscription -TenantId $CurrentTenantId -ErrorAction Stop

      # Check if any of the current subscriptions match the ones in the list
      foreach ($subscription in $AllSubscriptions) {
        if ($SubscriptionIdsToCheck -contains $subscription.SubscriptionId) {
          Write-Debug "Begin: Already logged into a tenant with one of the specified subscriptions.`n"
          Write-Host "Already logged into a tenant with one of the specified subscriptions.`n" -ForegroundColor Green
          $LoggedInState = $true
          break
        }
      }
    }
  } catch {
    Write-Error "Begin: Error occurred while checking current subscriptions: $_ `n"
  }
}
process {
  try {
    if (-not $LoggedInState) {
      Write-Debug "Process: Not logged into a tenant with any of the specified subscriptions. Authenticating to Azure. `n"
      $WamState = $null
      $LoginExperienceV2State = $null

      # Check if EnableLoginByWam is true
      $WamState = $null
      if ((Get-AzConfig -EnableLoginByWam).Value -eq $true) {
        Write-Debug "Process: Disabling interactive login experience (EnableLoginByWam).`n"
        $WamState = (Get-AzConfig -EnableLoginByWam).Value
        Set-AzConfig -EnableLoginByWam $false -WarningAction SilentlyContinue
      }

      # Check if LoginExperienceV2 is 'On'
      $LoginExperienceV2State = $null
      if ((Get-AzConfig -LoginExperienceV2).Value -eq 'On') {
        Write-Debug "Process: Disabling interactive login experience (LoginExperienceV2).`n"
        $LoginExperienceV2State = (Get-AzConfig -LoginExperienceV2).Value
        Update-AzConfig -LoginExperienceV2 Off -WarningAction SilentlyContinue
      }

      Write-Debug 'Process: Connecting to Azure.'
      # Connect to Azure using the first valid subscription ID
      $FirstValidSubscriptionId = $SubscriptionIdsToCheck | Select-Object -First 1
      Connect-AzAccount -Tenant $TenantID -Subscription $FirstValidSubscriptionId -WarningAction SilentlyContinue -Environment $AzureEnvironment

      if ($null -ne $WamState) {
        Write-Debug 'Process: Restoring interactive login experience (WamState).'
        Set-AzConfig -EnableLoginByWam $WamState -WarningAction SilentlyContinue
      }

      if ($null -ne $LoginExperienceV2State) {
        Write-Debug 'Process: Restoring interactive login experience (LoginExperienceV2State).'
        Update-AzConfig -LoginExperienceV2 $LoginExperienceV2State -WarningAction SilentlyContinue
      }
    } else {
      Write-Debug 'Process: Skipped login'
    }
  } catch {
    Write-Error "Process: Error occurred while authenticating to Azure: $_"
  }
}
end {
  try {
    Write-Debug 'End: Completed authentication to Azure.'
    $Script:SubIds = Get-AzSubscription -TenantId $TenantID
  } catch {
    Write-Error "End: Error occurred while retrieving subscriptions after logging in: $_"
  }
}
