function Test-IsAzureCloudShell {
  [CmdletBinding()]
  [OutputType([System.Boolean])]
  param()
  try {
    if ($null -ne $env:ACC_CLOUD) {
      "Running in Azure Cloud Shell environment, no need to explicitly authenticate. `n"
      return $true
    } else {
      return $false
    }
  } catch {
    Write-Error "An error occurred while checking the Azure Cloud Shell environment: $_ `n"
    return $false
  }
}
