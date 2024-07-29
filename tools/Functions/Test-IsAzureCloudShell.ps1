<#
  .SYNOPSIS
  Checks if the script is running in the Azure Cloud Shell environment.

  .DESCRIPTION
  The Test-IsAzureCloudShell function checks if the script is running in the Azure Cloud Shell environment.
  It does this by checking the value of the ACC_CLOUD environment variable. If the variable is not null,
  it means the script is running in Azure Cloud Shell.

  .EXAMPLE
  PS C:\> Test-IsAzureCloudShell
  Running in Azure Cloud Shell environment, no need to explicitly authenticate.

  .OUTPUTS
  System.Boolean
  Returns $true if running in Azure Cloud Shell, otherwise returns $false.

  .NOTES
  #>

[OutputType([System.Boolean])]
param()
'Running in Azure Cloud Shell environment, no need to explicitly authenticate.'
try {
  if ($null -ne $env:ACC_CLOUD) {
    Write-Output 'Running in Azure Cloud Shell environment, no needs to explicitly authenticate.'
    return $true
  } else {
    return $false
  }
} catch {
  Write-Error "An error occurred while checking the Azure Cloud Shell environment: $_"
  return $false
}
