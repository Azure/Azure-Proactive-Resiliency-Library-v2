#Requires -Version 7

Param(
  [switch]$Debugging,
  [switch]$SAP,
  [switch]$AVD,
  [switch]$AVS,
  [switch]$HPC,
  $CustomerName,
  $WorkloadName,
  $SubscriptionIds,
  $ResourceGroups,
  $TenantID,
  $Tags,
  [ValidateSet('AzureCloud', 'AzureUSGovernment')]
  $AzureEnvironment = 'AzureCloud',
  $ConfigFile,
  # Runbook parameters...
  [switch]$UseImplicitRunbookSelectors,
  $RunbookFile
)

$RunGuid = [guid]::NewGuid().ToString()
$Script1OutputPath = ".\1_$RunGuid.json"

Write-Host
Write-Host "1. Running WARA collector script [.\1_wara_collector.ps1]..." -ForegroundColor Cyan
Write-Host

.\1_wara_collector.ps1 `
  -Debugging:$Debugging `
  -SAP:$SAP `
  -AVD:$AVD `
  -AVS:$AVS `
  -HPC:$HPC `
  -SubscriptionIds:$SubscriptionIds `
  -ResourceGroups:$ResourceGroups `
  -TenantID:$TenantID `
  -Tags:$Tags `
  -AzureEnvironment:$AzureEnvironment `
  -ConfigFile:$ConfigFile `
  -OutputFile:$Script1OutputPath `
  -UseImplicitRunbookSelectors:$UseImplicitRunbookSelectors `
  -RunbookFile:$RunbookFile

if (!(Test-Path -Path $Script1OutputPath -PathType Leaf)) {
  Write-Error "1_wara_collector.ps1 did not produce an output file [$Script1OutputPath]. WARA run failed."
  Exit 1
}

$Script2OutputPath = ".\2_$RunGuid.xlsx"

Write-Host
Write-Host "2. Running WARA data analyzer script [.\2_wara_data_analyzer.ps1]..." -ForegroundColor Cyan
Write-Host

.\2_wara_data_analyzer.ps1 `
  -Debugging:$Debugging `
  -JSONFile:$Script1OutputPath `
  -OutputFile:$Script2OutputPath

if (!(Test-Path -Path $Script2OutputPath -PathType Leaf)) {
  Write-Error "2_wara_data_analyzer.ps1 did not produce an output file [$Script2OutputPath]. WARA run failed."
  Exit 1
}

Write-Host
Write-Host "3. Running WARA reports generator script [.\3_wara_reports_generator.ps1]..." -ForegroundColor Cyan
Write-Host

.\3_wara_reports_generator.ps1 `
  -Debugging:$Debugging `
  -CustomerName:$CustomerName `
  -WorkloadName:$WorkloadName `
  -ExcelFile:$Script2OutputPath `

Write-Host
Write-Host "All done!" -ForegroundColor Cyan
Write-Host
