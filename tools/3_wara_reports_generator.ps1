#Requires -Version 7

<#
.SYNOPSIS
Well-Architected Reliability Assessment Report Generator Script

.DESCRIPTION
The script "3_wara_reports_generator" processes the Excel file created by the "2_wara_data_analyzer" script and generates the final PowerPoint and Word reports for the Well-Architected Reliability Assessment.

.PARAMETER Help
Switch to display help information.

.PARAMETER Debugging
Switch to enable debugging mode.

.PARAMETER CustomerName
Name of the customer for whom the report is being generated.

.PARAMETER WorkloadName
Name of the workload being assessed.

.PARAMETER ExcelFile
Path to the Excel file created by the "2_wara_data_analyzer" script.

.PARAMETER Heavy
Switch to enable heavy processing mode. When enabled, this mode introduces additional delays using Start-Sleep at various points in the script to handle heavy environments more gracefully. This can help in scenarios where the system resources are limited or the operations being performed are resource-intensive, ensuring the script doesn't overwhelm the system.

.PARAMETER PPTTemplateFile
Path to the PowerPoint template file.

.PARAMETER WordTemplateFile
Path to the Word template file.

.EXAMPLE
.\3_wara_reports_generator.ps1 -ExcelFile 'C:\WARA_Script\WARA Action Plan 2024-03-07_16_06.xlsx' -CustomerName 'ABC Customer' -WorkloadName 'SAP On Azure' -Heavy -PPTTemplateFile 'C:\Templates\Template.pptx' -WordTemplateFile 'C:\Templates\Template.docx'

.LINK
https://github.com/Azure/Azure-Proactive-Resiliency-Library-v2
#>

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'False positive as Write-Host does not represent a security risk and this script will always run on host consoles')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '', Justification = 'False positive as parameters are not always required')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments','', Justification='Variable is reserved for future use')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars','', Justification='This will be fixed in refactor')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns','', Justification='This will be fixed in refactor')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions','', Justification='This will be fixed in refactor')]

    Param(
    [switch] $Help,
    #[switch] $GenerateCSV,
    #[switch] $includeLow,
    #[switch] $byPassValidationStatus,
    [switch] $Debugging,
    [string] $CustomerName,
    [string] $WorkloadName,
    [Parameter(mandatory = $true)]
    [string] $ExcelFile,
    [switch] $Heavy,
    [string] $PPTTemplateFile,
    [string] $WordTemplateFile
    )

    # Checking the operating system running this script.
    if (-not $IsWindows) {
    Write-Host 'This script only supports Windows operating systems currently. Please try to run with Windows operating systems.'
    Exit
    }

    if ($Heavy.IsPresent -or $GenerateCSV.IsPresent) { $Global:Heavy = $true } else { $Global:Heavy = $false }

    if ($Debugging.IsPresent) { $Global:CoreDebugging = $true } else { $Global:CoreDebugging = $false }

    if (!$PPTTemplateFile) {
            if ((Test-Path -Path ($PSScriptRoot + '\Mandatory - Executive Summary presentation - Template.pptx') -PathType Leaf) -eq $true) {
                    $PPTTemplateFile = ($PSScriptRoot + '\Mandatory - Executive Summary presentation - Template.pptx')
                }
            else {
                Write-Host "This script requires specific Microsoft PowerPoint and Word templates, which are available in the Azure Proactive Resiliency Library. You can download the templates from this GitHub repository:"
                Write-Host "https://github.com/Azure/Azure-Proactive-Resiliency-Library-v2/tree/main/tools"
                Exit
            }
        }
    else
        {
          $PPTTemplateFile = (Resolve-Path -Path $PPTTemplateFile).Path
            #$PPTTemplateFile = get-item -Path $PPTTemplateFile
            #$PPTTemplateFile = $PPTTemplateFile.FullName
        }


    if (!$WordTemplateFile) {
            if ((Test-Path -Path ($PSScriptRoot + '\Optional - Assessment Report - Template.docx') -PathType Leaf) -eq $true) {
                    $WordTemplateFile = ($PSScriptRoot + '\Optional - Assessment Report - Template.docx')
                }
            else {
                Write-Host "This script requires specific Microsoft PowerPoint and Word templates, which are available in the Azure Proactive Resiliency Library. You can download the templates from this GitHub repository:"
                Write-Host "https://github.com/Azure/Azure-Proactive-Resiliency-Library-v2/tree/main/tools"
                Exit
            }
        }
    else
        {
          $WordTemplateFile = (Resolve-Path -Path $WordTemplateFile).Path
            #$WordTemplateFile = get-item -Path $WordTemplateFile
            #$WordTemplateFile = $WordTemplateFile.FullName
        }

    if (!$CustomerName) {
    $CustomerName = '[Customer Name]'
    }

    if (!$WorkloadName) {
    $WorkloadName = '[Workload Name]'
    }

    function Get-HelpMessage {
    Write-Host ""
    Write-Host "Parameters"
    Write-Host ""
    Write-Host " -ExcelFile              :  Mandatory; WARA Excel file generated by '2_wara_data_analyzer.ps1' script and customized."
    Write-Host " -CustomerName           :  Optional; specifies the Name of the Customer to be added to the PPTx and DOCx files. "
    Write-Host " -WorkloadName           :  Optional; specifies the Name of the Workload of the analyses to be added to the PPTx and DOCx files. "
    Write-Host " -PPTTemplateFile        :  Optional; specifies the PPTx template file to be used as source. If not specified the script will look for the file in the same path as the script. "
    Write-Host " -WordTemplateFile       :  Optional; specifies the DOCx template file to be used as source. If not specified the script will look for the file in the same path as the script. "
    Write-Host " -GenerateCSV              :  Optional; when used will trigger the creation of a CSV File with the exported Impacted Resources. "
    Write-Host " -includeLow             :  Optional; only used in with -GenerateCSV to also include Low recommendations in the CSV File. "
    Write-Host " -byPassValidationStatus :  Optional; used to skip the High and Medium Resource Validation. "

    byPassValidationStatus
    Write-Host " -Debugging            :  Optional; writes Debugging information to the screen. "
    Write-Host ""
    Write-Host "Examples: "
    Write-Host ""
    Write-Host "  Running with Customer details"
    Write-Host "  .\3_wara_reports_generator.ps1 -ExcelFile 'C:\WARA_Script\WARA Action Plan 2024-03-07_16_06.xlsx' -CustomerName 'ABC Customer' -WorkloadName 'SAP On Azure'"
    Write-Host ""
    Write-Host ""
    Write-Host "  Running without Customer details"
    Write-Host "  .\3_wara_reports_generator.ps1 -ExcelFile 'C:\WARA_Script\WARA Action Plan 2024-03-07_16_06.xlsx'"
    Write-Host ""
    Write-Host ""
    }

    $Global:Runtime = Measure-Command -Expression {

    function Test-Requirement {
        # Install required modules
        Write-Host "Validating " -NoNewline
        Write-Host "ImportExcel" -ForegroundColor Cyan -NoNewline
        Write-Host " Module.."
        $ImportExcel = Get-Module -Name ImportExcel -ListAvailable -ErrorAction silentlycontinue
        if ($null -eq $ImportExcel)
        {
            Write-Host "Installing ImportExcel Module" -ForegroundColor Yellow
            Install-Module -Name ImportExcel -Force -SkipPublisherCheck
        }
    }
    function Set-LocalFolder {
        # Define script path as the default path to save files
        try
        {
            $workingFolderPath = $PSScriptRoot
            Set-Location -path $workingFolderPath;
            $Global:clonePath = "$workingFolderPath\Azure-Proactive-Resiliency-Library-v2"
            Write-Debug "Checking the version of the script"
            $RepoVersion = Get-Content -Path "$clonePath\tools\Version.json" -ErrorAction SilentlyContinue | ConvertFrom-Json
            if ($Version -ne $RepoVersion.Generator)
            {
                Write-Host "This version of the script is outdated. " -BackgroundColor DarkRed
                Write-Host "Please use a more recent version of the script." -BackgroundColor DarkRed
            }
            else
            {
                Write-Host "This version of the script is current version. " -BackgroundColor DarkGreen
            }
        }
        catch
        {
            $errorMessage = $_.Exception
            $ErrorStack = $_.ScriptStackTrace
            if ($Debugging.IsPresent) { ('LocalFiles - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Error - ' + $errorMessage) | Out-File -FilePath $LogFile -Append }
            if ($Debugging.IsPresent) { ('LocalFiles - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Error - ' + $ErrorStack) | Out-File -FilePath $LogFile -Append }
        }
    }
    function Get-Excel {

        if ($Debugging.IsPresent) { ('FunctExcel - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Processing Excel variables..') | Out-File -FilePath $LogFile -Append }

        if (-not (Test-Path -PathType Leaf -Path $ExcelFile))
        {
            Write-Error ('The specified Excel file "{0}" was not found.' -f $ExcelFile)
            Exit
        }
        $ExcelFile = get-item -Path $ExcelFile
        if ($Global:Heavy) {Start-Sleep -Milliseconds 100}
        $ExcelFile = $ExcelFile.FullName
        try
        {
            $Global:ExcelCore = Import-Excel -Path $ExcelFile
            if ($Global:Heavy) {Start-Sleep -Milliseconds 100}
            $Global:ExcelContent = Import-Excel -Path $ExcelFile -WorksheetName ImpactedResources
            $Global:ExcelRecommendations = Import-Excel -Path $ExcelFile -WorksheetName Recommendations
        }
        catch
        {
            $errorMessage = $_.Exception
            $ErrorStack = $_.ScriptStackTrace
            if ($CoreDebugging) { ('OfficeApps - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Error - ' + $errorMessage) | Out-File -FilePath $LogFile -Append }
            if ($CoreDebugging) { ('OfficeApps - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Error - ' + $ErrorStack) | Out-File -FilePath $LogFile -Append }
            if (($_.Exception -is [System.Management.Automation.MethodInvocationException]) -and ($_.Exception.Message -like '*encrypted*'))
            {
                Write-Error ('The specified Excel file "{0}" may be encrypted. If a sensitivity label is applied to the file, please change the sensitivity label to the label without encryption temporarily. Learn more: https://aka.ms/aprl/tools/faq' -f $ExcelFile)
            }
            else
            {
                Write-Error $errorMessage
            }
            Exit
        }

        Write-Progress -Id 1 -activity "Processing Office Apps" -Status "25% Complete." -PercentComplete 25

        $Global:Outages = try {
        if ($Global:Heavy) {Start-Sleep -Milliseconds 100}
        Import-Excel -Path $ExcelFile -WorksheetName Outages
        }
        catch {
        if ($Debugging.IsPresent) { ('FunctExcel - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Warn - Outages not found in the Excel File..') | Out-File -FilePath $LogFile -Append }
        }

        Write-Progress -Id 1 -activity "Processing Office Apps" -Status "30% Complete." -PercentComplete 30
        $Global:SupportTickets = try {
        if ($Global:Heavy) {Start-Sleep -Milliseconds 100}
        Import-Excel -Path $ExcelFile -WorksheetName "Support Tickets" -AsText 'Ticket ID'
        }
        catch {
        if ($Debugging.IsPresent) { ('FunctExcel - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Warn - Support Tickets not found in the Excel File..') | Out-File -FilePath $LogFile -Append }
        }

        Write-Progress -Id 1 -activity "Processing Office Apps" -Status "35% Complete." -PercentComplete 35
        $Global:ServiceHealth = try {
        if ($Global:Heavy) {Start-Sleep -Milliseconds 100}
        Import-Excel -Path $ExcelFile -WorksheetName "Health Alerts"
        }
        catch {
        if ($Debugging.IsPresent) { ('FunctExcel - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Warn - Service Health Alerts not found in the Excel File..') | Out-File -FilePath $LogFile -Append }
        }

        Write-Progress -Id 1 -activity "Processing Office Apps" -Status "40% Complete." -PercentComplete 40
        $Global:Retirements = try {
        if ($Global:Heavy) {Start-Sleep -Milliseconds 100}
        Import-Excel -Path $ExcelFile -WorksheetName "Retirements"
        }
        catch {
        if ($Debugging.IsPresent) { ('FunctExcel - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Warn - Service Retirements not found in the Excel File..') | Out-File -FilePath $LogFile -Append }
        }
    }
    function Test-Excel {
        Param($ExcelContent,$byPassValidationStatus)

        $Validation = $ExcelContent | Where-Object {$_.'How was the resource/recommendation validated or what actions need to be taken?' -like 'IMPORTANT *' -and $_.impact -in ('High','Medium')}

        if(![string]::IsNullOrEmpty($Validation) -and !($byPassValidationStatus.IsPresent))
            {
              Write-Host ''
              Write-Host 'There are High- and/or Medium-impact recommendations in the ImpactedResources worksheet that need manual validation. '
              Write-Host ''
              Write-Host 'Open the Action Plan, go to the ImpactedResources worksheet, click the filter in Column A, deselect "APRL - Queries" and "Advisor Queries" then click the filter in Column E, and deselect "Low".'
              Write-Host ''
              Write-Host 'Ensure all listed resources are validated before generating reports.'
              Write-Host ''
              Exit
            }
    }
    function Invoke-Orchestrator {

        Write-Progress -Id 1 -activity "Processing Office Apps" -Status "45% Complete." -PercentComplete 45
        if ($Debugging.IsPresent) { ('Funct_Orch - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Starting Orchestrator Function..') | Out-File -FilePath $LogFile -Append }
        Start-Job -Name 'OfficeApps' -ScriptBlock {

        $CoreDebugging = $($args[13])
        $LogFile = $($args[14])
        $Heavy = $($args[15])

        if ($CoreDebugging) { ('OfficeApps - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Setting Variables..') | Out-File -FilePath $LogFile -Append }

        try
            {
            $ExcelCore = $($args[0])
            $ExcelContent = $($args[1])
            $Outages = $($args[2])
            $SupportTickets = $($args[3])
            $ServiceHealth = $($args[4])
            $Retirements = $($args[5])
            $ExcelFile = $($args[6])

            $HighImpact = $ExcelCore | Where-Object { $_."Number of Impacted Resources?" -gt 0 -and $_.Impact -eq 'High' } | Sort-Object -Property "Number of Impacted Resources?" -Descending
            if ($Heavy) {Start-Sleep -Milliseconds 100}
            $MediumImpact = $ExcelCore | Where-Object { $_."Number of Impacted Resources?" -gt 0 -and $_.Impact -eq 'Medium' } | Sort-Object -Property "Number of Impacted Resources?" -Descending
            if ($Heavy) {Start-Sleep -Milliseconds 100}
            $LowImpact = $ExcelCore | Where-Object { $_."Number of Impacted Resources?" -gt 0 -and $_.Impact -eq 'Low' } | Sort-Object -Property "Number of Impacted Resources?" -Descending

            $ServiceHighImpact = $ExcelCore | Where-Object { $_."Number of Impacted Resources?" -gt 0 -and $_.Impact -eq 'High' -and $_.'Azure Service / Well-Architected' -eq 'Azure Service' } | Sort-Object -Property "Number of Impacted Resources?" -Descending
            if ($Heavy) {Start-Sleep -Milliseconds 100}
            $WAFHighImpact = $ExcelCore | Where-Object { $_."Number of Impacted Resources?" -gt 0 -and $_.Impact -eq 'High' -and $_.'Azure Service / Well-Architected' -eq 'Well Architected' } | Sort-Object -Property "Number of Impacted Resources?" -Descending

            $ResourceIDs = $ExcelContent.id | Select-Object -Unique -CaseInsensitive

            if ($CoreDebugging) { ('OfficeApps - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Processing Resource Types..') | Out-File -FilePath $LogFile -Append }
            $Resources = @()
            Foreach ($ID in $ResourceIDs)
            {
                if (![string]::IsNullOrEmpty($ID) -and $ID -ne 'n/a')
                    {
                        $obj = @{
                        'ID'             = $ID;
                        'Subscription'   = $ID.split('/')[2];
                        'Resource Group' = $ID.split('/')[4];
                        'Resource Type'  = ($ID.split('/')[6] + '/' + $ID.split('/')[7])
                        }
                        $Resources += $obj
                    }
            }

            $ResourcesTypes = $Resources | Group-Object -Property 'Resource Type' | Sort-Object -Property 'Count' -Descending | Select-Object -First 10

            if ($CoreDebugging) { ('OfficeApps - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Starting Excel..') | Out-File -FilePath $LogFile -Append }
            }
        catch
            {
            $errorMessage = $_.Exception
            $ErrorStack = $_.ScriptStackTrace
            if ($CoreDebugging) { ('OfficeApps - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Error - ' + $errorMessage) | Out-File -FilePath $LogFile -Append }
            if ($CoreDebugging) { ('OfficeApps - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Error - ' + $ErrorStack) | Out-File -FilePath $LogFile -Append }
            }

        try
            {
            $CustomerName = $($args[7])
            $WorkloadName = $($args[8])
            $PPTTemplateFile = $($args[9])
            $PPTFinalFile = $($args[10])
            $WordTemplateFile = $($args[11])
            $WordFinalFile = $($args[12])

            $ExcelApplication = New-Object -ComObject Excel.Application
            Start-Sleep 1
            if ($CoreDebugging) { ('OfficeApps - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Opening Excel file..') | Out-File -FilePath $LogFile -Append }
            # Resolve the full path of the Excel file
            $ExcelFileFullPath = (Resolve-Path -Path $ExcelFile).Path

            # Open the Excel file using the full path
            $Ex = $ExcelApplication.Workbooks.Open($ExcelFileFullPath)
            while ([string]::IsNullOrEmpty($Ex)) {
                Start-Sleep 2
                if ($CoreDebugging) { ('OfficeApps - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Waiting Excel document..') | Out-File -FilePath $LogFile -Append }
            }
            }
        catch
            {
            $errorMessage = $_.Exception
            $ErrorStack = $_.ScriptStackTrace
            if ($CoreDebugging) { ('OfficeApps - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Error - ' + $errorMessage) | Out-File -FilePath $LogFile -Append }
            if ($CoreDebugging) { ('OfficeApps - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Error - ' + $ErrorStack) | Out-File -FilePath $LogFile -Append }
            }

        $job = @()

        if ($CoreDebugging) { ('OfficeApps - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Setting PPT Thread..') | Out-File -FilePath $LogFile -Append }
        $PPT = ([PowerShell]::Create()).AddScript(
            {
            param($ResourcesTypes, $HighImpact, $MediumImpact, $LowImpact, $ServiceHighImpact, $WAFHighImpact, $ExcelContent, $Outages, $SupportTickets, $ServiceHealth, $Retirements, $Ex, $CustomerName, $WorkloadName, $ExcelCore, $PPTTemplateFile, $PPTFinalFile, $CoreDebugging, $Logfile, $Heavy)

            $Global:AUTOMESSAGE = 'AUTOMATICALLY MODIFIED (Please Review)'

            if ($CoreDebugging) { ('PPT_Thread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Starting PPT Thread..') | Out-File -FilePath $LogFile -Append }

            ############# Slide 1
            function Remove-Slide1 {
                if ($CoreDebugging) { ('PPT_Thread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Removing Slide 1..') | Out-File -FilePath $LogFile -Append }

                try
                {
                    ($pres.Slides | Where-Object { $_.SlideIndex -eq 1 }).Delete()
                    if ($Heavy) {Start-Sleep -Milliseconds 100}
                    $Slide1 = $pres.Slides | Where-Object { $_.SlideIndex -eq 1 }

                    if ($CoreDebugging) { ('PPT_Thread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Slide 1 - Adding Customer name: ' + $CustomerName + '. And Workload name: ' + $WorkloadName) | Out-File -FilePath $LogFile -Append }
                    ($Slide1.Shapes | Where-Object { $_.Id -eq 5 }).TextFrame.TextRange.Text = ($CustomerName + ' - ' + $WorkloadName)
                    if ($Heavy) {Start-Sleep -Milliseconds 100}
                }
                catch
                {
                    $errorMessage = $_.Exception
                    $ErrorStack = $_.ScriptStackTrace
                    if ($CoreDebugging) { ('PPT_Thread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Error - ' + $errorMessage) | Out-File -FilePath $LogFile -Append }
                    if ($CoreDebugging) { ('PPT_Thread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Error - ' + $ErrorStack) | Out-File -FilePath $LogFile -Append }
                }
            }

            ############# SLide 12
            function Build-Slide12 {
                if ($CoreDebugging) { ('PPT_Thread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Editing Slide 12 - Workload Summary..') | Out-File -FilePath $LogFile -Append }

                try
                {
                    $Slide12 = $pres.Slides | Where-Object { $_.SlideIndex -eq 12 }

                    $TargetShape = ($Slide12.Shapes | Where-Object { $_.Id -eq 9 })
                    $TargetShape.TextFrame.TextRange.Text = $AUTOMESSAGE

                    $TargetShape = ($Slide12.Shapes | Where-Object { $_.Id -eq 8 })
                    $TargetShape.Delete()
                    if ($Heavy) {Start-Sleep -Milliseconds 100}

                    if ($CoreDebugging) { ('PPT_Thread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Editing Slide 12 - Adding Workload name: ' + $WorkloadName) | Out-File -FilePath $LogFile -Append }
                    ($Slide12.Shapes | Where-Object { $_.Id -eq 3 }).TextFrame.TextRange.Text = ('During the engagement, the Workload ' + $WorkloadName + ' has been reviewed. The solution is hosted in two Azure regions, and runs mainly IaaS resources, with some PaaS resources, which includes but is not limited to:')

                    $loop = 1
                    foreach ($ResourcesType in $ResourcesTypes)
                    {
                        $LogResName = $ResourcesType.Name
                        $LogResCount = $ResourcesType.'Count'
                        if ($CoreDebugging) { ('PPT_Thread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Editing Slide 12 - Adding Resource Type: ' + $LogResName + '. Count: ' + $LogResCount) | Out-File -FilePath $LogFile -Append }
                        if ($loop -eq 1)
                        {
                            $ResourceTemp = ($ResourcesType.Name + ' (' + $ResourcesType.'Count' + ')')
                            ($Slide12.Shapes | Where-Object { $_.Id -eq 6 }).Table.Columns(1).Width = 685
                            ($Slide12.Shapes | Where-Object { $_.Id -eq 6 }).Table.Rows(1).Cells(1).Shape.TextFrame.TextRange.Text = $ResourceTemp
                            ($Slide12.Shapes | Where-Object { $_.Id -eq 6 }).Table.Rows(1).Height = 20
                        }
                        else
                        {
                            $ResourceTemp = ($ResourcesType.Name + ' (' + $ResourcesType.'Count' + ')')
                            ($Slide12.Shapes | Where-Object { $_.Id -eq 6 }).Table.Rows.Add() | Out-Null
                            ($Slide12.Shapes | Where-Object { $_.Id -eq 6 }).Table.Rows($loop).Cells(1).Shape.TextFrame.TextRange.Text = $ResourceTemp
                        }
                        if ($Heavy) {Start-Sleep -Milliseconds 200}
                        $loop ++
                    }
                }
                catch
                {
                    $errorMessage = $_.Exception
                    $ErrorStack = $_.ScriptStackTrace
                    if ($CoreDebugging) { ('PPT_Thread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Error - ' + $errorMessage) | Out-File -FilePath $LogFile -Append }
                    if ($CoreDebugging) { ('PPT_Thread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Error - ' + $ErrorStack) | Out-File -FilePath $LogFile -Append }
                }
            }

            ############# Slide 16
            function Build-Slide16 {
                if ($CoreDebugging) { ('PPT_Thread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Editing Slide 16 - Health and Risk Dashboard..') | Out-File -FilePath $LogFile -Append }

                try
                {
                    $Slide16 = $pres.Slides | Where-Object { $_.SlideIndex -eq 16 }

                    $TargetShape = ($Slide16.Shapes | Where-Object { $_.Id -eq 41 })
                    $TargetShape.TextFrame.TextRange.Text = $AUTOMESSAGE

                    $count = 1
                    foreach ($Impact in $ServiceHighImpact)
                    {
                        $LogImpactName = $Impact.'Recommendation Title'
                        if ($CoreDebugging) { ('PPT_Thread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Editing Slide 16 - Adding Service High Impact Name: ' + $LogImpactName) | Out-File -FilePath $LogFile -Append }
                        if ($count -le 5)
                        {
                            ($Slide16.Shapes | Where-Object { $_.Id -eq 9 }).TextFrame.TextRange.Paragraphs($count).text = $Impact.'Recommendation Title'
                            $count ++
                        }
                        if ($Heavy) {Start-Sleep -Milliseconds 100}
                    }

                    while (($Slide16.Shapes | Where-Object { $_.Id -eq 9 }).TextFrame.TextRange.Paragraphs().count -gt 5)
                    {
                        ($Slide16.Shapes | Where-Object { $_.Id -eq 9 }).TextFrame.TextRange.Paragraphs(6).Delete()
                        if ($Heavy) {Start-Sleep -Milliseconds 100}
                    }

                    if ($WAFHighImpact.count -ne 0)
                    {
                        $count = 1
                        foreach ($Impact in $WAFHighImpact)
                        {
                            $LogWAFImpactName = $Impact.'Recommendation Title'
                            if ($CoreDebugging) { ('PPT_Thread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Editing Slide 16 - Adding WAF High Impact: ' + $LogWAFImpactName) | Out-File -FilePath $LogFile -Append }
                            if ($count -lt 5)
                            {
                                ($Slide16.Shapes | Where-Object { $_.Id -eq 12 }).TextFrame.TextRange.Paragraphs($count).text = $Impact.'Recommendation Title'
                                $count ++
                            }
                            if ($Heavy) {Start-Sleep -Milliseconds 100}
                        }
                    }
                    else
                    {
                        ($Slide16.Shapes | Where-Object { $_.Id -eq 12 }).TextFrame.TextRange.Text = ' '
                    }

                    while (($Slide16.Shapes | Where-Object { $_.Id -eq 12 }).TextFrame.TextRange.Paragraphs().count -gt 5)
                    {
                        ($Slide16.Shapes | Where-Object { $_.Id -eq 12 }).TextFrame.TextRange.Paragraphs(6).Delete()
                    }

                    if ($CoreDebugging) { ('PPT_Thread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Editing Slide 16 - Adding general values...') | Out-File -FilePath $LogFile -Append }
                    #Total Recomendations
                    ($Slide16.Shapes | Where-Object { $_.Id -eq 44 }).GroupItems[3].TextFrame.TextRange.Text = [string]($ExcelCore | Where-Object { $_."Number of Impacted Resources?" -gt 0 }).count
                    if ($Heavy) {Start-Sleep -Milliseconds 100}
                    #High Impact
                    ($Slide16.Shapes | Where-Object { $_.Id -eq 44 }).GroupItems[4].TextFrame.TextRange.Text = [string]($ExcelCore | Where-Object { $_."Number of Impacted Resources?" -gt 0 -and $_.Impact -eq 'High' }).count
                    if ($Heavy) {Start-Sleep -Milliseconds 100}
                    #Medium Impact
                    ($Slide16.Shapes | Where-Object { $_.Id -eq 44 }).GroupItems[5].TextFrame.TextRange.Text = [string]($ExcelCore | Where-Object { $_."Number of Impacted Resources?" -gt 0 -and $_.Impact -eq 'Medium' }).count
                    if ($Heavy) {Start-Sleep -Milliseconds 100}
                    #Low Impact
                    ($Slide16.Shapes | Where-Object { $_.Id -eq 44 }).GroupItems[6].TextFrame.TextRange.Text = [string]($ExcelCore | Where-Object { $_."Number of Impacted Resources?" -gt 0 -and $_.Impact -eq 'Low' }).count
                    if ($Heavy) {Start-Sleep -Milliseconds 100}
                    #Impacted Resources
                    ($Slide16.Shapes | Where-Object { $_.Id -eq 44 }).GroupItems[7].TextFrame.TextRange.Text = [string]($ExcelContent.id | Where-Object { ![string]::IsNullOrEmpty($_) } | Select-Object -Unique -CaseInsensitive).count
                    if ($Heavy) {Start-Sleep -Milliseconds 100}
                }
                catch
                {
                    $errorMessage = $_.Exception
                    $ErrorStack = $_.ScriptStackTrace
                    if ($CoreDebugging) { ('PPT_Thread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Error - ' + $errorMessage) | Out-File -FilePath $LogFile -Append }
                    if ($CoreDebugging) { ('PPT_Thread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Error - ' + $ErrorStack) | Out-File -FilePath $LogFile -Append }
                }
            }

            ############# Slide 17
            function Build-Slide17 {
                if ($CoreDebugging) { ('PPT_Thread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Editing Slide 17 - Health and Risk Dashboard..') | Out-File -FilePath $LogFile -Append }

                try
                {
                    $Slide17 = $pres.Slides | Where-Object { $_.SlideIndex -eq 17 }

                    $TargetShape = ($Slide17.Shapes | Where-Object { $_.Id -eq 41 })
                    $TargetShape.TextFrame.TextRange.Text = $AUTOMESSAGE

                    if ($CoreDebugging) { ('PPT_Thread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Editing Slide 17 - Looking Charts in Excel File...') | Out-File -FilePath $LogFile -Append }
                    $WS2 = $Ex.Worksheets | Where-Object { $_.Name -eq 'Charts' }

                    if ($CoreDebugging) { ('PPT_Thread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Editing Slide 17 - Replacing Chart 1..') | Out-File -FilePath $LogFile -Append }
                    #Copy Excel Chart0
                    ($Slide17.Shapes | Where-Object { $_.Id -eq 3 }).Chart.Delete()
                    if ($Heavy) {Start-Sleep -Milliseconds 500} else {Start-Sleep -Milliseconds 100}
                    $WS2.ChartObjects('ChartP0').copy()
                    if ($Heavy) {Start-Sleep -Milliseconds 500} else {Start-Sleep -Milliseconds 100}
                    $Slide17.Shapes.Paste() | Out-Null
                    Start-Sleep 2
                    foreach ($Shape in $Slide17.Shapes)
                    {
                        if ($Shape.Name -eq 'ChartP0')
                        {
                            $Shape.IncrementLeft(240)
                        }
                    }

                    if ($CoreDebugging) { ('PPT_Thread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Editing Slide 17 - Replacing Chart 2..') | Out-File -FilePath $LogFile -Append }
                    #Copy Excel Chart1
                    ($Slide17.Shapes | Where-Object { $_.Id -eq 5 }).Chart.Delete()
                    if ($Heavy) {Start-Sleep -Milliseconds 500} else {Start-Sleep -Milliseconds 100}
                    $WS2.ChartObjects('ChartP1').copy()
                    if ($Heavy) {Start-Sleep -Milliseconds 500} else {Start-Sleep -Milliseconds 100}
                    $Slide17.Shapes.Paste() | Out-Null
                    Start-Sleep 2
                    foreach ($Shape in $Slide17.Shapes)
                    {
                        if ($Shape.Name -eq 'ChartP1')
                        {
                            $Shape.IncrementLeft(-260)
                            $Shape.IncrementTop(45)
                        }
                    }
                }
                catch
                {
                    $errorMessage = $_.Exception
                    $ErrorStack = $_.ScriptStackTrace
                    if ($CoreDebugging) { ('PPT_Thread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Error - ' + $errorMessage) | Out-File -FilePath $LogFile -Append }
                    if ($CoreDebugging) { ('PPT_Thread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Error - ' + $ErrorStack) | Out-File -FilePath $LogFile -Append }
                }
            }

            ############# Slide 21
            function Build-Slide21 {
                if ($CoreDebugging) { ('PPT_Thread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Editing Slide 21 - Service Health Alerts..') | Out-File -FilePath $LogFile -Append }

                try
                {
                    $FirstSlide = 21
                    $TableID = 6
                    $CurrentSlide = $pres.Slides | Where-Object { $_.SlideIndex -eq $FirstSlide }
                    $CoreSlide = $pres.Slides | Where-Object { $_.SlideIndex -eq $FirstSlide }

                    $TargetShape = ($CurrentSlide.Shapes | Where-Object { $_.Id -eq 41 })
                    $TargetShape.TextFrame.TextRange.Text = $AUTOMESSAGE

                    if ($CoreDebugging) { ('PPT_Thread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Editing Slide 21 - Cleaning Table..') | Out-File -FilePath $LogFile -Append }
                    $row = 3
                    while ($row -lt 2)
                    {
                        $cell = 1
                        while ($cell -lt 9)
                        {
                            ($CurrentSlide.Shapes | Where-Object { $_.Id -eq $TableID }).Table.Rows($row).Cells($cell).Shape.TextFrame.TextRange.Text = ''
                            $Cell ++
                            if ($Heavy) {Start-Sleep -Milliseconds 100}
                        }
                        $row ++
                    }

                    $Counter = 1
                    $row = 3
                    foreach ($Health in $Global:ServiceHealth)
                    {
                        $LogHealthName = $Health.Name
                        if ($CoreDebugging) { ('PPT_Thread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Editing Slide 21 - Adding Service Health Alert: ' + $LogHealthName) | Out-File -FilePath $LogFile -Append }
                        if ($Counter -lt 17)
                        {
                            ($CurrentSlide.Shapes | Where-Object { $_.Id -eq $TableID }).Table.Rows($row).Cells(1).Shape.TextFrame.TextRange.Text = [string]$Health.Subscription
                            ($CurrentSlide.Shapes | Where-Object { $_.Id -eq $TableID }).Table.Rows($row).Cells(2).Shape.TextFrame.TextRange.Text = [string]$Health.Name
                            ($CurrentSlide.Shapes | Where-Object { $_.Id -eq $TableID }).Table.Rows($row).Cells(3).Shape.TextFrame.TextRange.Text = if ($Health.Services -eq 'All') { 'Yes' }else { 'No' }
                            ($CurrentSlide.Shapes | Where-Object { $_.Id -eq $TableID }).Table.Rows($row).Cells(4).Shape.TextFrame.TextRange.Text = if ($Health.Regions -eq 'All') { 'Yes' }else { 'No' }
                            ($CurrentSlide.Shapes | Where-Object { $_.Id -eq $TableID }).Table.Rows($row).Cells(5).Shape.TextFrame.TextRange.Text = if ($Health.'Event Type' -like '*Service Issues*' -or $Health.'Event Type' -eq 'All') { 'Yes' }else { 'No' }
                            ($CurrentSlide.Shapes | Where-Object { $_.Id -eq $TableID }).Table.Rows($row).Cells(6).Shape.TextFrame.TextRange.Text = if ($Health.'Event Type' -like '*Planned Maintenance*' -or $Health.'Event Type' -eq 'All') { 'Yes' }else { 'No' }
                            ($CurrentSlide.Shapes | Where-Object { $_.Id -eq $TableID }).Table.Rows($row).Cells(7).Shape.TextFrame.TextRange.Text = if ($Health.'Event Type' -like '*Health Advisories*' -or $Health.'Event Type' -eq 'All') { 'Yes' }else { 'No' }
                            ($CurrentSlide.Shapes | Where-Object { $_.Id -eq $TableID }).Table.Rows($row).Cells(8).Shape.TextFrame.TextRange.Text = if ($Health.'Event Type' -like '*Security Advisory*' -or $Health.'Event Type' -eq 'All') { 'Yes' }else { 'No' }
                            ($CurrentSlide.Shapes | Where-Object { $_.Id -eq $TableID }).Table.Rows($row).Cells(9).Shape.TextFrame.TextRange.Text = ' '
                            $counter ++
                            $row ++
                        }
                        else
                        {
                            if ($CoreDebugging) { ('PPT_Thread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Editing Slide 21 - Creating new slide for Service Health Alerts..') | Out-File -FilePath $LogFile -Append }
                            $Counter = 1
                            $CustomLayout = $CurrentSlide.CustomLayout
                            $FirstSlide ++
                            $pres.Slides.addSlide($FirstSlide, $customLayout) | Out-Null

                            $NextSlide = $pres.Slides | Where-Object { $_.SlideIndex -eq $FirstSlide }
                            ($CoreSlide.Shapes | Where-Object { $_.Id -eq 4 }).TextFrame.TextRange.Copy()
                            if ($Heavy) {Start-Sleep -Milliseconds 500} else {Start-Sleep -Milliseconds 100}
                            ($NextSlide.Shapes | Where-Object { $_.Id -eq 2 }).TextFrame.TextRange.Paste() | Out-Null
                            if ($Heavy) {Start-Sleep -Milliseconds 500} else {Start-Sleep -Milliseconds 100}
                            ($CurrentSlide.Shapes | Where-Object { $_.Id -eq $TableID }).Copy()
                            if ($Heavy) {Start-Sleep -Milliseconds 500} else {Start-Sleep -Milliseconds 100}
                            $NextSlide.Shapes.Paste() | Out-Null
                            if ($Heavy) {Start-Sleep -Milliseconds 500} else {Start-Sleep -Milliseconds 100}
                            $TableID = 3
                            ($CoreSlide.Shapes | Where-Object { $_.Id -eq 41 }).Copy()
                            if ($Heavy) {Start-Sleep -Milliseconds 500} else {Start-Sleep -Milliseconds 100}
                            $NextSlide.Shapes.Paste() | Out-Null
                            if ($Heavy) {Start-Sleep -Milliseconds 500} else {Start-Sleep -Milliseconds 100}

                            $rowTemp = 2
                            while ($rowTemp -lt 18)
                            {
                                $cell = 1
                                while ($cell -lt 5)
                                {
                                    ($NextSlide.Shapes | Where-Object { $_.Id -eq $TableID }).Table.Rows($rowTemp).Cells($cell).Shape.TextFrame.TextRange.Text = ''
                                    $Cell ++
                                }
                                $rowTemp ++
                            }

                            $CurrentSlide = $NextSlide

                            $row = 3
                            ($CurrentSlide.Shapes | Where-Object { $_.Id -eq $TableID }).Table.Rows($row).Cells(1).Shape.TextFrame.TextRange.Text = [string]$Health.Subscription
                            ($CurrentSlide.Shapes | Where-Object { $_.Id -eq $TableID }).Table.Rows($row).Cells(2).Shape.TextFrame.TextRange.Text = [string]$Health.Name
                            ($CurrentSlide.Shapes | Where-Object { $_.Id -eq $TableID }).Table.Rows($row).Cells(3).Shape.TextFrame.TextRange.Text = if ($Health.Services -eq 'All') { 'Yes' }else { 'No' }
                            ($CurrentSlide.Shapes | Where-Object { $_.Id -eq $TableID }).Table.Rows($row).Cells(4).Shape.TextFrame.TextRange.Text = if ($Health.Regions -eq 'All') { 'Yes' }else { 'No' }
                            ($CurrentSlide.Shapes | Where-Object { $_.Id -eq $TableID }).Table.Rows($row).Cells(5).Shape.TextFrame.TextRange.Text = if ($Health.'Event Type' -like '*Service Issues*' -or $Health.'Event Type' -eq 'All') { 'Yes' }else { 'No' }
                            ($CurrentSlide.Shapes | Where-Object { $_.Id -eq $TableID }).Table.Rows($row).Cells(6).Shape.TextFrame.TextRange.Text = if ($Health.'Event Type' -like '*Planned Maintenance*' -or $Health.'Event Type' -eq 'All') { 'Yes' }else { 'No' }
                            ($CurrentSlide.Shapes | Where-Object { $_.Id -eq $TableID }).Table.Rows($row).Cells(7).Shape.TextFrame.TextRange.Text = if ($Health.'Event Type' -like '*Health Advisories*' -or $Health.'Event Type' -eq 'All') { 'Yes' }else { 'No' }
                            ($CurrentSlide.Shapes | Where-Object { $_.Id -eq $TableID }).Table.Rows($row).Cells(8).Shape.TextFrame.TextRange.Text = if ($Health.'Event Type' -like '*Security Advisory*' -or $Health.'Event Type' -eq 'All') { 'Yes' }else { 'No' }
                            ($CurrentSlide.Shapes | Where-Object { $_.Id -eq $TableID }).Table.Rows($row).Cells(9).Shape.TextFrame.TextRange.Text = ' '
                            $Counter ++
                            $row ++
                        }
                    }
                }
                catch
                {
                    $errorMessage = $_.Exception
                    $ErrorStack = $_.ScriptStackTrace
                    if ($CoreDebugging) { ('PPT_Thread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Error - ' + $errorMessage) | Out-File -FilePath $LogFile -Append }
                    if ($CoreDebugging) { ('PPT_Thread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Error - ' + $ErrorStack) | Out-File -FilePath $LogFile -Append }
                }
            }

            ############# Slide 23
            function Build-Slide23 {
                if ($CoreDebugging) { ('PPT_Thread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Editing Slide 23 - High Impact Issues..') | Out-File -FilePath $LogFile -Append }

                try
                {
                    $FirstSlide = 23
                    $TableID = 6
                    $CurrentSlide = $pres.Slides | Where-Object { $_.SlideIndex -eq $FirstSlide }
                    $CoreSlide = $pres.Slides | Where-Object { $_.SlideIndex -eq $FirstSlide }

                    $TargetShape = ($CurrentSlide.Shapes | Where-Object { $_.Id -eq 41 })
                    $TargetShape.TextFrame.TextRange.Text = $AUTOMESSAGE

                    if ($CoreDebugging) { ('PPT_Thread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Editing Slide 23 - Cleaning Table..') | Out-File -FilePath $LogFile -Append }
                    $row = 2
                    while ($row -lt 6)
                    {
                        $cell = 1
                        while ($cell -lt 5)
                        {
                            ($CurrentSlide.Shapes | Where-Object { $_.Id -eq $TableID }).Table.Rows($row).Cells($cell).Shape.TextFrame.TextRange.Text = ''
                            $Cell ++
                            if ($Heavy) {Start-Sleep -Milliseconds 100}
                        }
                        $row ++
                    }

                    $Counter = 1
                    $RecomNumber = 1
                    $row = 2
                    foreach ($Impact in $HighImpact)
                    {
                        $LogHighImpact = $Impact.'Recommendation Title'
                        if ($CoreDebugging) { ('PPT_Thread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Editing Slide 23 - Adding High Impact: ' + $LogHighImpact ) | Out-File -FilePath $LogFile -Append }
                        if ($Counter -lt 14)
                        {
                            #Number
                            ($CurrentSlide.Shapes | Where-Object { $_.Id -eq $TableID }).Table.Rows($row).Cells(1).Shape.TextFrame.TextRange.Text = [string]$RecomNumber
                            #Recommendation
                            ($CurrentSlide.Shapes | Where-Object { $_.Id -eq $TableID }).Table.Rows($row).Cells(2).Shape.TextFrame.TextRange.Text = $Impact.'Recommendation Title'
                            #Service
                            if ($Impact.'Azure Service / Well-Architected' -eq 'Well Architected') {
                            $ServiceName = ('WAF - ' + $Impact.'Azure Service / Well-Architected Topic')
                            }
                            else {
                            $ServiceName = $Impact.'Azure Service / Well-Architected Topic'
                            }
                            ($CurrentSlide.Shapes | Where-Object { $_.Id -eq $TableID }).Table.Rows($row).Cells(3).Shape.TextFrame.TextRange.Text = $ServiceName
                            #Impacted Resources
                            ($CurrentSlide.Shapes | Where-Object { $_.Id -eq $TableID }).Table.Rows($row).Cells(4).Shape.TextFrame.TextRange.Text = [string]$Impact.'Number of Impacted Resources?'
                            $counter ++
                            $RecomNumber ++
                            $row ++
                        }
                        else
                        {
                            if ($CoreDebugging) { ('PPT_Thread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Editing Slide 23 - Adding new Slide..') | Out-File -FilePath $LogFile -Append }
                            $Counter = 1
                            $CustomLayout = $CurrentSlide.CustomLayout
                            $FirstSlide ++
                            $pres.Slides.addSlide($FirstSlide, $customLayout) | Out-Null

                            $NextSlide = $pres.Slides | Where-Object { $_.SlideIndex -eq $FirstSlide }
                            ($CoreSlide.Shapes | Where-Object { $_.Id -eq 4 }).TextFrame.TextRange.Copy()
                            if ($Heavy) {Start-Sleep -Milliseconds 500} else {Start-Sleep -Milliseconds 100}
                            ($NextSlide.Shapes | Where-Object { $_.Id -eq 2 }).TextFrame.TextRange.Paste() | Out-Null
                            if ($Heavy) {Start-Sleep -Milliseconds 500} else {Start-Sleep -Milliseconds 100}
                            ($CurrentSlide.Shapes | Where-Object { $_.Id -eq $TableID }).Copy()
                            if ($Heavy) {Start-Sleep -Milliseconds 500} else {Start-Sleep -Milliseconds 100}
                            $NextSlide.Shapes.Paste() | Out-Null
                            if ($Heavy) {Start-Sleep -Milliseconds 500} else {Start-Sleep -Milliseconds 100}
                            $TableID = 3
                            ($CoreSlide.Shapes | Where-Object { $_.Id -eq 41 }).Copy()
                            if ($Heavy) {Start-Sleep -Milliseconds 500} else {Start-Sleep -Milliseconds 100}
                            $NextSlide.Shapes.Paste() | Out-Null
                            if ($Heavy) {Start-Sleep -Milliseconds 500} else {Start-Sleep -Milliseconds 100}

                            if ($CoreDebugging) { ('PPT_Thread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Editing Slide 23 - Cleaning table of new slide..') | Out-File -FilePath $LogFile -Append }
                            $rowTemp = 2
                            while ($rowTemp -lt 15)
                            {
                                $cell = 1
                                while ($cell -lt 5)
                                {
                                    ($NextSlide.Shapes | Where-Object { $_.Id -eq $TableID }).Table.Rows($rowTemp).Cells($cell).Shape.TextFrame.TextRange.Text = ''
                                    $Cell ++
                                    if ($Heavy) {Start-Sleep -Milliseconds 100}
                                }
                                $rowTemp ++
                            }

                            $CurrentSlide = $NextSlide

                            $row = 2
                            #Number
                            ($CurrentSlide.Shapes | Where-Object { $_.Id -eq $TableID }).Table.Rows($row).Cells(1).Shape.TextFrame.TextRange.Text = [string]$RecomNumber
                            #Recommendation
                            ($CurrentSlide.Shapes | Where-Object { $_.Id -eq $TableID }).Table.Rows($row).Cells(2).Shape.TextFrame.TextRange.Text = $Impact.'Recommendation Title'
                            #Service
                            if ($Impact.'Azure Service / Well-Architected' -eq 'Well Architected')
                            {
                                $ServiceName = ('WAF - ' + $Impact.'Azure Service / Well-Architected Topic')
                            }
                            else
                            {
                                $ServiceName = $Impact.'Azure Service / Well-Architected Topic'
                            }
                            ($CurrentSlide.Shapes | Where-Object { $_.Id -eq $TableID }).Table.Rows($row).Cells(3).Shape.TextFrame.TextRange.Text = $ServiceName
                            #Impacted Resources
                            ($CurrentSlide.Shapes | Where-Object { $_.Id -eq $TableID }).Table.Rows($row).Cells(4).Shape.TextFrame.TextRange.Text = [string]$Impact.'Number of Impacted Resources?'
                            $Counter ++
                            $RecomNumber ++
                            $row ++
                            if ($Heavy) {Start-Sleep -Milliseconds 100}
                        }
                    }
                }
                catch
                {
                    $errorMessage = $_.Exception
                    $ErrorStack = $_.ScriptStackTrace
                    if ($CoreDebugging) { ('PPT_Thread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Error - ' + $errorMessage) | Out-File -FilePath $LogFile -Append }
                    if ($CoreDebugging) { ('PPT_Thread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Error - ' + $ErrorStack) | Out-File -FilePath $LogFile -Append }
                }
            }

            ############# Slide 24
            function Build-Slide24 {
                if ($CoreDebugging) { ('PPT_Thread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Editing Slide 24 - Medium Impact Issues..') | Out-File -FilePath $LogFile -Append }

                try
                {
                    $FirstSlide = 24
                    $TableID = 6
                    $CurrentSlide = $pres.Slides | Where-Object { $_.SlideIndex -eq $FirstSlide }
                    $CoreSlide = $pres.Slides | Where-Object { $_.SlideIndex -eq $FirstSlide }

                    $TargetShape = ($CurrentSlide.Shapes | Where-Object { $_.Id -eq 41 })
                    $TargetShape.TextFrame.TextRange.Text = $AUTOMESSAGE

                    if ($CoreDebugging) { ('PPT_Thread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Editing Slide 24 - Cleaning Table..') | Out-File -FilePath $LogFile -Append }
                    $row = 2
                    while ($row -lt 6)
                    {
                        $cell = 1
                        while ($cell -lt 5)
                        {
                            ($CurrentSlide.Shapes | Where-Object { $_.Id -eq $TableID }).Table.Rows($row).Cells($cell).Shape.TextFrame.TextRange.Text = ''
                            $Cell ++
                            if ($Heavy) {Start-Sleep -Milliseconds 100}
                        }
                        $row ++
                    }

                    $Counter = 1
                    $RecomNumber = 1
                    $row = 2
                    foreach ($Impact in $MediumImpact)
                    {
                        $LogMediumImpact = $Impact.'Recommendation Title'
                        if ($CoreDebugging) { ('PPT_Thread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Editing Slide 24 - Adding Medium Impact: ' + $LogMediumImpact) | Out-File -FilePath $LogFile -Append }
                        if ($Counter -lt 14)
                        {
                            #Number
                            ($CurrentSlide.Shapes | Where-Object { $_.Id -eq $TableID }).Table.Rows($row).Cells(1).Shape.TextFrame.TextRange.Text = [string]$RecomNumber
                            #Recommendation
                            ($CurrentSlide.Shapes | Where-Object { $_.Id -eq $TableID }).Table.Rows($row).Cells(2).Shape.TextFrame.TextRange.Text = $Impact.'Recommendation Title'
                            #Service
                            if ($Impact.'Azure Service / Well-Architected' -eq 'Well Architected')
                            {
                                $ServiceName = ('WAF - ' + $Impact.'Azure Service / Well-Architected Topic')
                            }
                            else
                            {
                                $ServiceName = $Impact.'Azure Service / Well-Architected Topic'
                            }
                            ($CurrentSlide.Shapes | Where-Object { $_.Id -eq $TableID }).Table.Rows($row).Cells(3).Shape.TextFrame.TextRange.Text = $ServiceName
                            #Impacted Resources
                            ($CurrentSlide.Shapes | Where-Object { $_.Id -eq $TableID }).Table.Rows($row).Cells(4).Shape.TextFrame.TextRange.Text = [string]$Impact.'Number of Impacted Resources?'
                            $counter ++
                            $RecomNumber ++
                            $row ++
                            if ($Heavy) {Start-Sleep -Milliseconds 100}
                        }
                        else
                        {
                            if ($CoreDebugging) { ('PPT_Thread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Editing Slide 24 - Creating new slide..') | Out-File -FilePath $LogFile -Append }
                            $Counter = 1
                            $CustomLayout = $CurrentSlide.CustomLayout
                            $FirstSlide ++
                            $pres.Slides.addSlide($FirstSlide, $customLayout) | Out-Null

                            $NextSlide = $pres.Slides | Where-Object { $_.SlideIndex -eq $FirstSlide }
                            ($CoreSlide.Shapes | Where-Object { $_.Id -eq 4 }).TextFrame.TextRange.Copy()
                            if ($Heavy) {Start-Sleep -Milliseconds 500} else {Start-Sleep -Milliseconds 100}
                            ($NextSlide.Shapes | Where-Object { $_.Id -eq 2 }).TextFrame.TextRange.Paste() | Out-Null
                            if ($Heavy) {Start-Sleep -Milliseconds 500} else {Start-Sleep -Milliseconds 100}
                            ($CurrentSlide.Shapes | Where-Object { $_.Id -eq $TableID }).Copy()
                            if ($Heavy) {Start-Sleep -Milliseconds 500} else {Start-Sleep -Milliseconds 100}
                            $NextSlide.Shapes.Paste() | Out-Null
                            if ($Heavy) {Start-Sleep -Milliseconds 500} else {Start-Sleep -Milliseconds 100}
                            $TableID = 3
                            ($CoreSlide.Shapes | Where-Object { $_.Id -eq 41 }).Copy()
                            if ($Heavy) {Start-Sleep -Milliseconds 500} else {Start-Sleep -Milliseconds 100}
                            $NextSlide.Shapes.Paste() | Out-Null
                            if ($Heavy) {Start-Sleep -Milliseconds 500} else {Start-Sleep -Milliseconds 100}

                            if ($CoreDebugging) { ('PPT_Thread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Editing Slide 24 - Cleaning Table of new slide..') | Out-File -FilePath $LogFile -Append }
                            $rowTemp = 2
                            while ($rowTemp -lt 15)
                            {
                                $cell = 1
                                while ($cell -lt 5)
                                {
                                    ($NextSlide.Shapes | Where-Object { $_.Id -eq $TableID }).Table.Rows($rowTemp).Cells($cell).Shape.TextFrame.TextRange.Text = ''
                                    $Cell ++
                                }
                                $rowTemp ++
                            }

                            $CurrentSlide = $NextSlide

                            $row = 2
                            #Number
                            ($CurrentSlide.Shapes | Where-Object { $_.Id -eq $TableID }).Table.Rows($row).Cells(1).Shape.TextFrame.TextRange.Text = [string]$RecomNumber
                            #Recommendation
                            ($CurrentSlide.Shapes | Where-Object { $_.Id -eq $TableID }).Table.Rows($row).Cells(2).Shape.TextFrame.TextRange.Text = $Impact.'Recommendation Title'
                            #Service
                            if ($Impact.'Azure Service / Well-Architected' -eq 'Well Architected')
                            {
                                $ServiceName = ('WAF - ' + $Impact.'Azure Service / Well-Architected Topic')
                            }
                            else
                            {
                                $ServiceName = $Impact.'Azure Service / Well-Architected Topic'
                            }
                            ($CurrentSlide.Shapes | Where-Object { $_.Id -eq $TableID }).Table.Rows($row).Cells(3).Shape.TextFrame.TextRange.Text = $ServiceName
                            #Impacted Resources
                            ($CurrentSlide.Shapes | Where-Object { $_.Id -eq $TableID }).Table.Rows($row).Cells(4).Shape.TextFrame.TextRange.Text = [string]$Impact.'Number of Impacted Resources?'
                            $Counter ++
                            $RecomNumber ++
                            $row ++
                            if ($Heavy) {Start-Sleep -Milliseconds 100}
                        }
                    }
                }
                catch
                {
                    $errorMessage = $_.Exception
                    $ErrorStack = $_.ScriptStackTrace
                    if ($CoreDebugging) { ('PPT_Thread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Error - ' + $errorMessage) | Out-File -FilePath $LogFile -Append }
                    if ($CoreDebugging) { ('PPT_Thread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Error - ' + $ErrorStack) | Out-File -FilePath $LogFile -Append }
                }
            }

            ############# Slide 25
            function Build-Slide25 {
                if ($CoreDebugging) { ('PPT_Thread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Editing Slide 25 - Low Impact Issues..') | Out-File -FilePath $LogFile -Append }

                try
                {
                    $FirstSlide = 25
                    $TableID = 6
                    $CurrentSlide = $pres.Slides | Where-Object { $_.SlideIndex -eq $FirstSlide }
                    $CoreSlide = $pres.Slides | Where-Object { $_.SlideIndex -eq $FirstSlide }

                    $TargetShape = ($CurrentSlide.Shapes | Where-Object { $_.Id -eq 41 })
                    $TargetShape.TextFrame.TextRange.Text = $AUTOMESSAGE

                    if ($CoreDebugging) { ('PPT_Thread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Editing Slide 25 - Cleaning Table..') | Out-File -FilePath $LogFile -Append }
                    $row = 2
                    while ($row -lt 6)
                    {
                        $cell = 1
                        while ($cell -lt 5)
                        {
                            ($CurrentSlide.Shapes | Where-Object { $_.Id -eq $TableID }).Table.Rows($row).Cells($cell).Shape.TextFrame.TextRange.Text = ''
                            $Cell ++
                            if ($Heavy) {Start-Sleep -Milliseconds 100}
                        }
                        $row ++
                    }

                    $Counter = 1
                    $RecomNumber = 1
                    $row = 2
                    foreach ($Impact in $LowImpact)
                    {
                        $LogLowImpact = $Impact.'Recommendation Title'
                        if ($CoreDebugging) { ('PPT_Thread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Editing Slide 25 - Adding Low Impact: ' + $LogLowImpact) | Out-File -FilePath $LogFile -Append }
                        if ($Counter -lt 14)
                        {
                            #Number
                            ($CurrentSlide.Shapes | Where-Object { $_.Id -eq $TableID }).Table.Rows($row).Cells(1).Shape.TextFrame.TextRange.Text = [string]$RecomNumber
                            #Recommendation
                            ($CurrentSlide.Shapes | Where-Object { $_.Id -eq $TableID }).Table.Rows($row).Cells(2).Shape.TextFrame.TextRange.Text = $Impact.'Recommendation Title'
                            #Service
                            if ($Impact.'Azure Service / Well-Architected' -eq 'Well Architected')
                            {
                                $ServiceName = ('WAF - ' + $Impact.'Azure Service / Well-Architected Topic')
                            }
                            else
                            {
                                $ServiceName = $Impact.'Azure Service / Well-Architected Topic'
                            }
                            ($CurrentSlide.Shapes | Where-Object { $_.Id -eq $TableID }).Table.Rows($row).Cells(3).Shape.TextFrame.TextRange.Text = $ServiceName
                            #Impacted Resources
                            ($CurrentSlide.Shapes | Where-Object { $_.Id -eq $TableID }).Table.Rows($row).Cells(4).Shape.TextFrame.TextRange.Text = [string]$Impact.'Number of Impacted Resources?'
                            $counter ++
                            $RecomNumber ++
                            $row ++
                            if ($Heavy) {Start-Sleep -Milliseconds 100}
                        }
                        else
                        {
                            if ($CoreDebugging) { ('PPT_Thread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Editing Slide 25 - Creating new Slide..') | Out-File -FilePath $LogFile -Append }
                            $Counter = 1
                            $CustomLayout = $CurrentSlide.CustomLayout
                            $FirstSlide ++
                            $pres.Slides.addSlide($FirstSlide, $customLayout) | Out-Null

                            $NextSlide = $pres.Slides | Where-Object { $_.SlideIndex -eq $FirstSlide }
                            ($CoreSlide.Shapes | Where-Object { $_.Id -eq 4 }).TextFrame.TextRange.Copy()
                            if ($Heavy) {Start-Sleep -Milliseconds 500} else {Start-Sleep -Milliseconds 100}
                            ($NextSlide.Shapes | Where-Object { $_.Id -eq 2 }).TextFrame.TextRange.Paste() | Out-Null
                            if ($Heavy) {Start-Sleep -Milliseconds 500} else {Start-Sleep -Milliseconds 100}
                            ($CurrentSlide.Shapes | Where-Object { $_.Id -eq $TableID }).Copy()
                            if ($Heavy) {Start-Sleep -Milliseconds 500} else {Start-Sleep -Milliseconds 100}
                            $NextSlide.Shapes.Paste() | Out-Null
                            if ($Heavy) {Start-Sleep -Milliseconds 500} else {Start-Sleep -Milliseconds 100}
                            $TableID = 3
                            ($CoreSlide.Shapes | Where-Object { $_.Id -eq 41 }).Copy()
                            if ($Heavy) {Start-Sleep -Milliseconds 500} else {Start-Sleep -Milliseconds 100}
                            $NextSlide.Shapes.Paste() | Out-Null
                            if ($Heavy) {Start-Sleep -Milliseconds 500} else {Start-Sleep -Milliseconds 100}

                            if ($CoreDebugging) { ('PPT_Thread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Editing Slide 25 - Cleaning Table of new slide..') | Out-File -FilePath $LogFile -Append }
                            $rowTemp = 2
                            while ($rowTemp -lt 15)
                            {
                                $cell = 1
                                while ($cell -lt 5)
                                {
                                    ($NextSlide.Shapes | Where-Object { $_.Id -eq $TableID }).Table.Rows($rowTemp).Cells($cell).Shape.TextFrame.TextRange.Text = ''
                                    $Cell ++
                                    if ($Heavy) {Start-Sleep -Milliseconds 100}
                                }
                                $rowTemp ++
                            }

                            $CurrentSlide = $NextSlide

                            $row = 2
                            #Number
                            ($CurrentSlide.Shapes | Where-Object { $_.Id -eq $TableID }).Table.Rows($row).Cells(1).Shape.TextFrame.TextRange.Text = [string]$RecomNumber
                            #Recommendation
                            ($CurrentSlide.Shapes | Where-Object { $_.Id -eq $TableID }).Table.Rows($row).Cells(2).Shape.TextFrame.TextRange.Text = $Impact.'Recommendation Title'
                            #Service
                            if ($Impact.'Azure Service / Well-Architected' -eq 'Well Architected')
                            {
                                $ServiceName = ('WAF - ' + $Impact.'Azure Service / Well-Architected Topic')
                            }
                            else
                            {
                                $ServiceName = $Impact.'Azure Service / Well-Architected Topic'
                            }
                            ($CurrentSlide.Shapes | Where-Object { $_.Id -eq $TableID }).Table.Rows($row).Cells(3).Shape.TextFrame.TextRange.Text = $ServiceName
                            #Impacted Resources
                            ($CurrentSlide.Shapes | Where-Object { $_.Id -eq $TableID }).Table.Rows($row).Cells(4).Shape.TextFrame.TextRange.Text = [string]$Impact.'Number of Impacted Resources?'
                            $Counter ++
                            $RecomNumber ++
                            $row ++
                            if ($Heavy) {Start-Sleep -Milliseconds 100}
                        }
                    }
                }
                catch
                {
                    $errorMessage = $_.Exception
                    $ErrorStack = $_.ScriptStackTrace
                    if ($CoreDebugging) { ('PPT_Thread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Error - ' + $errorMessage) | Out-File -FilePath $LogFile -Append }
                    if ($CoreDebugging) { ('PPT_Thread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Error - ' + $ErrorStack) | Out-File -FilePath $LogFile -Append }
                }
            }

            ############# Slide 28
            function Build-Slide28 {
                if ($CoreDebugging) { ('PPT_Thread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Editing Slide 28 - Recent Microsoft Outages..') | Out-File -FilePath $LogFile -Append }

                try
                {
                    $Loop = 1
                    $CurrentSlide = 28

                    if (![string]::IsNullOrEmpty($Global:Outages))
                    {
                        if ($CoreDebugging) { ('PPT_Thread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Editing Slide 28 - Outages found..') | Out-File -FilePath $LogFile -Append }
                        foreach ($Outage in $Global:Outages)
                        {
                            if ($Loop -eq 1)
                            {
                                $OutageName = ($Outage.'Tracking ID' + ' - ' + $Outage.title)
                                if ($CoreDebugging) { ('PPT_Thread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Editing Slide 28 - Adding Outage: ' + $OutageName) | Out-File -FilePath $LogFile -Append }

                                $OutageService = $Outage.'Impacted Service'

                                $Slide28 = $pres.Slides | Where-Object { $_.SlideIndex -eq 28 }

                                $TargetShape = ($Slide28.Shapes | Where-Object { $_.Id -eq 4 })
                                $TargetShape.TextFrame.TextRange.Text = $AUTOMESSAGE

                                ($Slide28.Shapes | Where-Object { $_.Id -eq 7 }).TextFrame.TextRange.Paragraphs(1).Text = $OutageName
                                ($Slide28.Shapes | Where-Object { $_.Id -eq 7 }).TextFrame.TextRange.Paragraphs(2).Text = "What happened:"
                                ($Slide28.Shapes | Where-Object { $_.Id -eq 7 }).TextFrame.TextRange.Paragraphs(3).Text = $Outage.'What happened'
                                ($Slide28.Shapes | Where-Object { $_.Id -eq 7 }).TextFrame.TextRange.Paragraphs(2).Copy()
                                if ($Heavy) {Start-Sleep -Milliseconds 500} else {Start-Sleep -Milliseconds 100}
                                ($Slide28.Shapes | Where-Object { $_.Id -eq 7 }).TextFrame.TextRange.Paragraphs(4).Paste() | Out-Null
                                if ($Heavy) {Start-Sleep -Milliseconds 500} else {Start-Sleep -Milliseconds 100}
                                ($Slide28.Shapes | Where-Object { $_.Id -eq 7 }).TextFrame.TextRange.Paragraphs(4).Text = "Impacted Service:"
                                ($Slide28.Shapes | Where-Object { $_.Id -eq 7 }).TextFrame.TextRange.Paragraphs(3).Copy()
                                if ($Heavy) {Start-Sleep -Milliseconds 500} else {Start-Sleep -Milliseconds 100}
                                ($Slide28.Shapes | Where-Object { $_.Id -eq 7 }).TextFrame.TextRange.Paragraphs(5).Paste() | Out-Null
                                if ($Heavy) {Start-Sleep -Milliseconds 500} else {Start-Sleep -Milliseconds 100}
                                ($Slide28.Shapes | Where-Object { $_.Id -eq 7 }).TextFrame.TextRange.Paragraphs(5).Text = $OutageService
                                ($Slide28.Shapes | Where-Object { $_.Id -eq 7 }).TextFrame.TextRange.Paragraphs(4).Copy()
                                if ($Heavy) {Start-Sleep -Milliseconds 500} else {Start-Sleep -Milliseconds 100}
                                ($Slide28.Shapes | Where-Object { $_.Id -eq 7 }).TextFrame.TextRange.Paragraphs(6).Paste() | Out-Null
                                if ($Heavy) {Start-Sleep -Milliseconds 500} else {Start-Sleep -Milliseconds 100}
                                ($Slide28.Shapes | Where-Object { $_.Id -eq 7 }).TextFrame.TextRange.Paragraphs(6).Text = "How can customers make incidents like this less impactful:"
                                ($Slide28.Shapes | Where-Object { $_.Id -eq 7 }).TextFrame.TextRange.Paragraphs(5).Copy()
                                if ($Heavy) {Start-Sleep -Milliseconds 500} else {Start-Sleep -Milliseconds 100}
                                ($Slide28.Shapes | Where-Object { $_.Id -eq 7 }).TextFrame.TextRange.Paragraphs(7).Paste() | Out-Null
                                if ($Heavy) {Start-Sleep -Milliseconds 500} else {Start-Sleep -Milliseconds 100}
                                ($Slide28.Shapes | Where-Object { $_.Id -eq 7 }).TextFrame.TextRange.Paragraphs(7).Text = $Outage.'How can customers make incidents like this less impactful'

                                while (($Slide28.Shapes | Where-Object { $_.Id -eq 7 }).TextFrame.TextRange.Paragraphs().count -gt 7)
                                {
                                    ($Slide28.Shapes | Where-Object { $_.Id -eq 7 }).TextFrame.TextRange.Paragraphs(8).Delete()
                                }
                            }
                            else
                            {
                                if ($CoreDebugging) { ('PPT_Thread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Editing Slide 28 - Creating new Slide..') | Out-File -FilePath $LogFile -Append }
                                ############### NEXT 9 SLIDES

                                $OutageName = ($Outage.'Tracking ID' + ' - ' + $Outage.title)
                                if ($CoreDebugging) { ('PPT_Thread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Editing Slide 28 - Adding Outage: ' + $OutageName) | Out-File -FilePath $LogFile -Append }

                                $OutageService = $Outage.'Impacted Service'
                                $CustomLayout = $Slide28.CustomLayout
                                $pres.Slides.addSlide($CurrentSlide, $customLayout) | Out-Null

                                $NextSlide = $pres.Slides | Where-Object { $_.SlideIndex -eq $CurrentSlide }

                                ($Slide28.Shapes | Where-Object { $_.Id -eq 6 }).TextFrame.TextRange.Copy()
                                if ($Heavy) {Start-Sleep -Milliseconds 500} else {Start-Sleep -Milliseconds 100}

                                ($NextSlide.Shapes | Where-Object { $_.Id -eq 2 }).TextFrame.TextRange.Paste() | Out-Null
                                if ($Heavy) {Start-Sleep -Milliseconds 500} else {Start-Sleep -Milliseconds 100}

                                ($Slide28.Shapes | Where-Object { $_.Id -eq 4 }).Copy()
                                if ($Heavy) {Start-Sleep -Milliseconds 500} else {Start-Sleep -Milliseconds 100}

                                $NextSlide.Shapes.Paste() | Out-Null
                                if ($Heavy) {Start-Sleep -Milliseconds 500} else {Start-Sleep -Milliseconds 100}

                                ($Slide28.Shapes | Where-Object { $_.Id -eq 7 }).Copy()
                                if ($Heavy) {Start-Sleep -Milliseconds 500} else {Start-Sleep -Milliseconds 100}

                                $NextSlide.Shapes.Paste() | Out-Null
                                if ($Heavy) {Start-Sleep -Milliseconds 500} else {Start-Sleep -Milliseconds 100}

                                ($NextSlide.Shapes | Where-Object { $_.Id -eq 4 }).TextFrame.TextRange.Paragraphs(1).Text = $OutageName
                                ($NextSlide.Shapes | Where-Object { $_.Id -eq 4 }).TextFrame.TextRange.Paragraphs(2).Text = "What happened:"
                                ($NextSlide.Shapes | Where-Object { $_.Id -eq 4 }).TextFrame.TextRange.Paragraphs(3).Text = $Outage.'What happened'
                                ($NextSlide.Shapes | Where-Object { $_.Id -eq 4 }).TextFrame.TextRange.Paragraphs(2).Copy()
                                if ($Heavy) {Start-Sleep -Milliseconds 500} else {Start-Sleep -Milliseconds 100}
                                ($NextSlide.Shapes | Where-Object { $_.Id -eq 4 }).TextFrame.TextRange.Paragraphs(4).Paste() | Out-Null
                                if ($Heavy) {Start-Sleep -Milliseconds 500} else {Start-Sleep -Milliseconds 100}
                                ($NextSlide.Shapes | Where-Object { $_.Id -eq 4 }).TextFrame.TextRange.Paragraphs(4).Text = "Impacted Service:"
                                ($NextSlide.Shapes | Where-Object { $_.Id -eq 4 }).TextFrame.TextRange.Paragraphs(3).Copy()
                                if ($Heavy) {Start-Sleep -Milliseconds 500} else {Start-Sleep -Milliseconds 100}
                                ($NextSlide.Shapes | Where-Object { $_.Id -eq 4 }).TextFrame.TextRange.Paragraphs(5).Paste() | Out-Null
                                if ($Heavy) {Start-Sleep -Milliseconds 500} else {Start-Sleep -Milliseconds 100}
                                ($NextSlide.Shapes | Where-Object { $_.Id -eq 4 }).TextFrame.TextRange.Paragraphs(5).Text = $OutageService
                                ($NextSlide.Shapes | Where-Object { $_.Id -eq 4 }).TextFrame.TextRange.Paragraphs(4).Copy()
                                if ($Heavy) {Start-Sleep -Milliseconds 500} else {Start-Sleep -Milliseconds 100}
                                ($NextSlide.Shapes | Where-Object { $_.Id -eq 4 }).TextFrame.TextRange.Paragraphs(6).Paste() | Out-Null
                                if ($Heavy) {Start-Sleep -Milliseconds 500} else {Start-Sleep -Milliseconds 100}
                                ($NextSlide.Shapes | Where-Object { $_.Id -eq 4 }).TextFrame.TextRange.Paragraphs(6).Text = "How can customers make incidents like this less impactful:"
                                ($NextSlide.Shapes | Where-Object { $_.Id -eq 4 }).TextFrame.TextRange.Paragraphs(5).Copy()
                                if ($Heavy) {Start-Sleep -Milliseconds 500} else {Start-Sleep -Milliseconds 100}
                                ($NextSlide.Shapes | Where-Object { $_.Id -eq 4 }).TextFrame.TextRange.Paragraphs(7).Paste() | Out-Null
                                if ($Heavy) {Start-Sleep -Milliseconds 500} else {Start-Sleep -Milliseconds 100}
                                ($NextSlide.Shapes | Where-Object { $_.Id -eq 4 }).TextFrame.TextRange.Paragraphs(7).Text = $Outage.'How can customers make incidents like this less impactful'

                                ($Slide28.Shapes | Where-Object { $_.Id -eq 31 }).Copy()

                                $NextSlide.Shapes.Paste() | Out-Null

                                while (($NextSlide.Shapes | Where-Object { $_.Id -eq 4 }).TextFrame.TextRange.Paragraphs().count -gt 7)
                                {
                                    ($NextSlide.Shapes | Where-Object { $_.Id -eq 4 }).TextFrame.TextRange.Paragraphs(8).Delete()
                                    if ($Heavy) {Start-Sleep -Milliseconds 100}
                                }
                            }
                            $Loop ++
                            $CurrentSlide ++
                        }
                    }
                }
                catch
                {
                    $errorMessage = $_.Exception
                    $ErrorStack = $_.ScriptStackTrace
                    if ($CoreDebugging) { ('PPT_Thread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Error - ' + $errorMessage) | Out-File -FilePath $LogFile -Append }
                    if ($CoreDebugging) { ('PPT_Thread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Error - ' + $ErrorStack) | Out-File -FilePath $LogFile -Append }
                }
            }

            ############# Slide 29
            function Build-Slide29 {
                if ($CoreDebugging) { ('PPT_Thread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Editing Slide 29 - Sev-A Support Requests..') | Out-File -FilePath $LogFile -Append }

                try
                {
                    $Loop = 1
                    $CurrentSlide = 29
                    $Slide = 1

                    if (![string]::IsNullOrEmpty($Global:SupportTickets))
                    {
                        if ($CoreDebugging) { ('PPT_Thread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Editing Slide 29 - Support Tickets found..') | Out-File -FilePath $LogFile -Append }
                        foreach ($Tickets in $Global:SupportTickets)
                        {
                            $TicketName = ($Tickets.'Ticket ID' + ' - ' + $Tickets.Title)
                            if ($CoreDebugging) { ('PPT_Thread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Editing Slide 29 - Adding Ticket: ' + $TicketName) | Out-File -FilePath $LogFile -Append }
                            $TicketStatus = $Tickets.'Status'
                            $TicketDate = $Tickets.'Creation Date'

                            if ($Slide -eq 1)
                            {
                                if ($Loop -eq 1)
                                {
                                    $Slide29 = $pres.Slides | Where-Object { $_.SlideIndex -eq 29 }
                                    $TargetShape = ($Slide29.Shapes | Where-Object { $_.Id -eq 4 })
                                    $TargetShape.TextFrame.TextRange.Text = $AUTOMESSAGE

                                    ($Slide29.Shapes | Where-Object { $_.Id -eq 7 }).TextFrame.TextRange.Paragraphs(1).Text = $TicketName
                                    ($Slide29.Shapes | Where-Object { $_.Id -eq 7 }).TextFrame.TextRange.Paragraphs(2).Text = "Status: $TicketStatus"
                                    ($Slide29.Shapes | Where-Object { $_.Id -eq 7 }).TextFrame.TextRange.Paragraphs(3).Text = "Creation Date: $TicketDate"
                                    ($Slide29.Shapes | Where-Object { $_.Id -eq 7 }).TextFrame.TextRange.Paragraphs(3).Copy()
                                    if ($Heavy) {Start-Sleep -Milliseconds 100}
                                    ($Slide29.Shapes | Where-Object { $_.Id -eq 7 }).TextFrame.TextRange.Paragraphs(4).Paste() | Out-Null
                                    if ($Heavy) {Start-Sleep -Milliseconds 300}
                                    ($Slide29.Shapes | Where-Object { $_.Id -eq 7 }).TextFrame.TextRange.Paragraphs(4).Text = "Recommendation: "

                                    while (($Slide29.Shapes | Where-Object { $_.Id -eq 7 }).TextFrame.TextRange.Paragraphs().count -gt 4)
                                    {
                                        ($Slide29.Shapes | Where-Object { $_.Id -eq 7 }).TextFrame.TextRange.Paragraphs(5).Delete()
                                        if ($Heavy) {Start-Sleep -Milliseconds 200}
                                    }
                                    $ParagraphLoop = 5
                                    $Loop ++
                                }
                                else
                                {
                                    ($Slide29.Shapes | Where-Object { $_.Id -eq 7 }).TextFrame.TextRange.InsertAfter(".") | Out-Null
                                    ($Slide29.Shapes | Where-Object { $_.Id -eq 7 }).TextFrame.TextRange.Paragraphs(1).Copy()
                                    if ($Heavy) {Start-Sleep -Milliseconds 500} else {Start-Sleep -Milliseconds 100}
                                    ($Slide29.Shapes | Where-Object { $_.Id -eq 7 }).TextFrame.TextRange.Paragraphs($ParagraphLoop).Paste() | Out-Null
                                    if ($Heavy) {Start-Sleep -Milliseconds 500} else {Start-Sleep -Milliseconds 100}
                                    ($Slide29.Shapes | Where-Object { $_.Id -eq 7 }).TextFrame.TextRange.Paragraphs($ParagraphLoop).Text = $TicketName
                                    $ParagraphLoop ++
                                    ($Slide29.Shapes | Where-Object { $_.Id -eq 7 }).TextFrame.TextRange.InsertAfter(".") | Out-Null
                                    ($Slide29.Shapes | Where-Object { $_.Id -eq 7 }).TextFrame.TextRange.Paragraphs(2).Copy()
                                    if ($Heavy) {Start-Sleep -Milliseconds 500} else {Start-Sleep -Milliseconds 100}
                                    ($Slide29.Shapes | Where-Object { $_.Id -eq 7 }).TextFrame.TextRange.Paragraphs($ParagraphLoop).Paste() | Out-Null
                                    if ($Heavy) {Start-Sleep -Milliseconds 500} else {Start-Sleep -Milliseconds 100}
                                    ($Slide29.Shapes | Where-Object { $_.Id -eq 7 }).TextFrame.TextRange.Paragraphs($ParagraphLoop).Text = "Status: $TicketStatus"
                                    $ParagraphLoop ++
                                    ($Slide29.Shapes | Where-Object { $_.Id -eq 7 }).TextFrame.TextRange.InsertAfter(".") | Out-Null
                                    ($Slide29.Shapes | Where-Object { $_.Id -eq 7 }).TextFrame.TextRange.Paragraphs(3).Copy()
                                    if ($Heavy) {Start-Sleep -Milliseconds 500} else {Start-Sleep -Milliseconds 100}
                                    ($Slide29.Shapes | Where-Object { $_.Id -eq 7 }).TextFrame.TextRange.Paragraphs($ParagraphLoop).Paste() | Out-Null
                                    if ($Heavy) {Start-Sleep -Milliseconds 500} else {Start-Sleep -Milliseconds 100}
                                    ($Slide29.Shapes | Where-Object { $_.Id -eq 7 }).TextFrame.TextRange.Paragraphs($ParagraphLoop).Text = "Creation Date: $TicketDate"
                                    $ParagraphLoop ++
                                    ($Slide29.Shapes | Where-Object { $_.Id -eq 7 }).TextFrame.TextRange.InsertAfter(".") | Out-Null
                                    ($Slide29.Shapes | Where-Object { $_.Id -eq 7 }).TextFrame.TextRange.Paragraphs(4).Copy()
                                    if ($Heavy) {Start-Sleep -Milliseconds 500} else {Start-Sleep -Milliseconds 100}
                                    ($Slide29.Shapes | Where-Object { $_.Id -eq 7 }).TextFrame.TextRange.Paragraphs($ParagraphLoop).Paste() | Out-Null
                                    if ($Heavy) {Start-Sleep -Milliseconds 500} else {Start-Sleep -Milliseconds 100}
                                    ($Slide29.Shapes | Where-Object { $_.Id -eq 7 }).TextFrame.TextRange.Paragraphs($ParagraphLoop).Text = "Recommendation: "
                                    $ParagraphLoop ++

                                    if ($Loop -eq 4)
                                    {
                                        $Loop = 1
                                        $Slide ++
                                        $CurrentSlide ++
                                    }
                                    else
                                    {
                                        $Loop ++
                                    }
                                    Start-Sleep -Milliseconds 500
                                }
                            }
                            else {
                            if ($Loop -eq 1) {
                                if ($CoreDebugging) { ('PPT_Thread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Editing Slide 29 - Adding new Slide..') | Out-File -FilePath $LogFile -Append }
                                $CustomLayout = $Slide29.CustomLayout
                                $pres.Slides.addSlide($CurrentSlide, $customLayout) | Out-Null

                                $NextSlide = $pres.Slides | Where-Object { $_.SlideIndex -eq $CurrentSlide }

                                ($Slide29.Shapes | Where-Object { $_.Id -eq 6 }).TextFrame.TextRange.Copy()
                                if ($Heavy) {Start-Sleep -Milliseconds 500} else {Start-Sleep -Milliseconds 200}

                                ($NextSlide.Shapes | Where-Object { $_.Id -eq 2 }).TextFrame.TextRange.Paste() | Out-Null
                                if ($Heavy) {Start-Sleep -Milliseconds 500} else {Start-Sleep -Milliseconds 100}

                                ($Slide29.Shapes | Where-Object { $_.Id -eq 4 }).Copy()
                                if ($Heavy) {Start-Sleep -Milliseconds 500} else {Start-Sleep -Milliseconds 200}

                                $NextSlide.Shapes.Paste() | Out-Null
                                if ($Heavy) {Start-Sleep -Milliseconds 500} else {Start-Sleep -Milliseconds 100}

                                ($Slide29.Shapes | Where-Object { $_.Id -eq 2 }).Copy()
                                if ($Heavy) {Start-Sleep -Milliseconds 500} else {Start-Sleep -Milliseconds 200}

                                $NextSlide.Shapes.Paste() | Out-Null
                                if ($Heavy) {Start-Sleep -Milliseconds 500} else {Start-Sleep -Milliseconds 100}

                                ($Slide29.Shapes | Where-Object { $_.Id -eq 7 }).Copy()
                                if ($Heavy) {Start-Sleep -Milliseconds 500} else {Start-Sleep -Milliseconds 200}

                                $NextSlide.Shapes.Paste() | Out-Null
                                if ($Heavy) {Start-Sleep -Milliseconds 500} else {Start-Sleep -Milliseconds 100}

                                ($NextSlide.Shapes | Where-Object { $_.Id -eq 9 }).TextFrame.TextRange.Paragraphs(1).Text = $TicketName
                                ($NextSlide.Shapes | Where-Object { $_.Id -eq 9 }).TextFrame.TextRange.Paragraphs(2).Text = "Status: $TicketStatus"
                                ($NextSlide.Shapes | Where-Object { $_.Id -eq 9 }).TextFrame.TextRange.Paragraphs(3).Text = "Creation Date: $TicketDate"
                                ($NextSlide.Shapes | Where-Object { $_.Id -eq 9 }).TextFrame.TextRange.Paragraphs(4).Text = "Recommendation: "

                                while (($NextSlide.Shapes | Where-Object { $_.Id -eq 9 }).TextFrame.TextRange.Paragraphs().count -gt 4)
                                {
                                    ($NextSlide.Shapes | Where-Object { $_.Id -eq 9 }).TextFrame.TextRange.Paragraphs(5).Delete()
                                    if ($Heavy) {Start-Sleep -Milliseconds 300}
                                }
                                $ParagraphLoop = 5
                                $Loop ++
                            }
                            else {
                                ($NextSlide.Shapes | Where-Object { $_.Id -eq 9 }).TextFrame.TextRange.InsertAfter(".") | Out-Null
                                ($NextSlide.Shapes | Where-Object { $_.Id -eq 9 }).TextFrame.TextRange.Paragraphs(1).Copy()
                                if ($Heavy) {Start-Sleep -Milliseconds 500} else {Start-Sleep -Milliseconds 100}
                                ($NextSlide.Shapes | Where-Object { $_.Id -eq 9 }).TextFrame.TextRange.Paragraphs($ParagraphLoop).Paste() | Out-Null
                                if ($Heavy) {Start-Sleep -Milliseconds 500} else {Start-Sleep -Milliseconds 100}
                                ($NextSlide.Shapes | Where-Object { $_.Id -eq 9 }).TextFrame.TextRange.Paragraphs($ParagraphLoop).Text = $TicketName
                                $ParagraphLoop ++
                                ($NextSlide.Shapes | Where-Object { $_.Id -eq 9 }).TextFrame.TextRange.InsertAfter(".") | Out-Null
                                ($NextSlide.Shapes | Where-Object { $_.Id -eq 9 }).TextFrame.TextRange.Paragraphs(2).Copy()
                                if ($Heavy) {Start-Sleep -Milliseconds 500} else {Start-Sleep -Milliseconds 100}
                                ($NextSlide.Shapes | Where-Object { $_.Id -eq 9 }).TextFrame.TextRange.Paragraphs($ParagraphLoop).Paste() | Out-Null
                                if ($Heavy) {Start-Sleep -Milliseconds 500} else {Start-Sleep -Milliseconds 100}
                                ($NextSlide.Shapes | Where-Object { $_.Id -eq 9 }).TextFrame.TextRange.Paragraphs($ParagraphLoop).Text = "Status: $TicketStatus"
                                $ParagraphLoop ++
                                ($NextSlide.Shapes | Where-Object { $_.Id -eq 9 }).TextFrame.TextRange.InsertAfter(".") | Out-Null
                                ($NextSlide.Shapes | Where-Object { $_.Id -eq 9 }).TextFrame.TextRange.Paragraphs(3).Copy()
                                if ($Heavy) {Start-Sleep -Milliseconds 500} else {Start-Sleep -Milliseconds 100}
                                ($NextSlide.Shapes | Where-Object { $_.Id -eq 9 }).TextFrame.TextRange.Paragraphs($ParagraphLoop).Paste() | Out-Null
                                if ($Heavy) {Start-Sleep -Milliseconds 500} else {Start-Sleep -Milliseconds 100}
                                ($NextSlide.Shapes | Where-Object { $_.Id -eq 9 }).TextFrame.TextRange.Paragraphs($ParagraphLoop).Text = "Creation Date: $TicketDate"
                                $ParagraphLoop ++
                                ($NextSlide.Shapes | Where-Object { $_.Id -eq 9 }).TextFrame.TextRange.InsertAfter(".") | Out-Null
                                ($NextSlide.Shapes | Where-Object { $_.Id -eq 9 }).TextFrame.TextRange.Paragraphs(4).Copy()
                                if ($Heavy) {Start-Sleep -Milliseconds 500} else {Start-Sleep -Milliseconds 100}
                                ($NextSlide.Shapes | Where-Object { $_.Id -eq 9 }).TextFrame.TextRange.Paragraphs($ParagraphLoop).Paste() | Out-Null
                                if ($Heavy) {Start-Sleep -Milliseconds 500} else {Start-Sleep -Milliseconds 100}
                                ($NextSlide.Shapes | Where-Object { $_.Id -eq 9 }).TextFrame.TextRange.Paragraphs($ParagraphLoop).Text = "Recommendation: "
                                $ParagraphLoop ++

                                if ($Loop -eq 4) {
                                $Loop = 1
                                $Slide ++
                                $CurrentSlide ++
                                }
                                else {
                                $Loop ++
                                }
                            }
                            }
                            Start-Sleep -Milliseconds 500
                        }
                    }
                }
                catch
                {
                    $errorMessage = $_.Exception
                    $ErrorStack = $_.ScriptStackTrace
                    if ($CoreDebugging) { ('PPT_Thread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Error - ' + $errorMessage) | Out-File -FilePath $LogFile -Append }
                    if ($CoreDebugging) { ('PPT_Thread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Error - ' + $ErrorStack) | Out-File -FilePath $LogFile -Append }
                }
            }

            ############# Slide 30
            function Build-Slide30 {
                if ($CoreDebugging) { ('PPT_Thread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Editing Slide 30 - Service Retirement Notifications..') | Out-File -FilePath $LogFile -Append }

                try
                {
                    $Loop = 1

                    if (![string]::IsNullOrEmpty($Global:Retirements))
                    {
                        if ($CoreDebugging) { ('PPT_Thread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Editing Slide 30 - Service Retirement found..') | Out-File -FilePath $LogFile -Append }
                        $Slide30 = $pres.Slides | Where-Object { $_.SlideIndex -eq 30 }

                        $TargetShape = ($Slide30.Shapes | Where-Object { $_.Id -eq 4 })
                        $TargetShape.TextFrame.TextRange.Text = $AUTOMESSAGE
                        #$TargetShape.Delete()

                        ($Slide30.Shapes | Where-Object { $_.Id -eq 7 }).TextFrame.TextRange.Paragraphs(1).Text = '.'

                        while (($Slide30.Shapes | Where-Object { $_.Id -eq 7 }).TextFrame.TextRange.Paragraphs().count -gt 2)
                        {
                            ($Slide30.Shapes | Where-Object { $_.Id -eq 7 }).TextFrame.TextRange.Paragraphs(2).Delete()
                            if ($Heavy) {Start-Sleep -Milliseconds 100}
                        }

                        foreach ($Retirement in $Global:Retirements)
                        {
                            if ($Loop -lt 15)
                            {
                                if ($Loop -eq 1)
                                {
                                    $RetireName = ($Retirement.'Tracking ID' + ' - ' + $Retirement.Status + ' : ' + $Retirement.title)
                                    if ($CoreDebugging) { ('PPT_Thread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Editing Slide 30 - Adding Retirement: ' + $RetireName) | Out-File -FilePath $LogFile -Append }

                                    ($Slide30.Shapes | Where-Object { $_.Id -eq 7 }).TextFrame.TextRange.Paragraphs(1).Text = $RetireName
                                    $Loop ++
                                }
                                else
                                {
                                    $RetireName = ($Retirement.'Tracking ID' + ' - ' + $Retirement.Status + ' : ' + $Retirement.title)

                                    ($Slide30.Shapes | Where-Object { $_.Id -eq 7 }).TextFrame.TextRange.InsertAfter(".") | Out-Null
                                    if ($Heavy) {Start-Sleep -Milliseconds 500} else {Start-Sleep -Milliseconds 100}
                                    ($Slide30.Shapes | Where-Object { $_.Id -eq 7 }).TextFrame.TextRange.Paragraphs(1).Copy()
                                    if ($Heavy) {Start-Sleep -Milliseconds 500} else {Start-Sleep -Milliseconds 100}
                                    ($Slide30.Shapes | Where-Object { $_.Id -eq 7 }).TextFrame.TextRange.Paragraphs($Loop).Paste() | Out-Null
                                    if ($Heavy) {Start-Sleep -Milliseconds 500} else {Start-Sleep -Milliseconds 100}
                                    ($Slide30.Shapes | Where-Object { $_.Id -eq 7 }).TextFrame.TextRange.Paragraphs($Loop).Text = $RetireName
                                    $Loop ++
                                }
                            }
                        }
                    }
                }
                catch
                {
                    $errorMessage = $_.Exception
                    $ErrorStack = $_.ScriptStackTrace
                    if ($CoreDebugging) { ('PPT_Thread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Error - ' + $errorMessage) | Out-File -FilePath $LogFile -Append }
                    if ($CoreDebugging) { ('PPT_Thread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Error - ' + $ErrorStack) | Out-File -FilePath $LogFile -Append }
                }
            }

            if ($CoreDebugging) { ('PPT_Thread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Starting PowerPoint..') | Out-File -FilePath $LogFile -Append }
            try
                {
                #Opening PPT
                $Global:Application = New-Object -ComObject PowerPoint.Application

                $Global:pres = $Application.Presentations.Open($PPTTemplateFile, $null, $null, $null)

                Remove-Slide1
                Build-Slide12
                Build-Slide16
                Build-Slide17

                Build-Slide30
                Build-Slide29
                Build-Slide28

                Build-Slide25
                Build-Slide24
                Build-Slide23

                Build-Slide21

                if ($CoreDebugging) { ('PPT_Thread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Closing PowerPoint..') | Out-File -FilePath $LogFile -Append }
                $Global:pres.SaveAs($PPTFinalFile)
                $Global:pres.Close()
                $Global:Application.Quit()
                }
            catch
                {
                $errorMessage = $_.Exception
                $ErrorStack = $_.ScriptStackTrace
                if ($CoreDebugging) { ('PPT_Thread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Error - ' + $errorMessage) | Out-File -FilePath $LogFile -Append }
                if ($CoreDebugging) { ('PPT_Thread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Error - ' + $ErrorStack) | Out-File -FilePath $LogFile -Append }
                }

            }).AddArgument($ResourcesTypes).AddArgument($HighImpact).AddArgument($MediumImpact).AddArgument($LowImpact).AddArgument($ServiceHighImpact).AddArgument($WAFHighImpact).AddArgument($ExcelContent).AddArgument($Outages).AddArgument($SupportTickets).AddArgument($ServiceHealth).AddArgument($Retirements).AddArgument($Ex).AddArgument($CustomerName).AddArgument($WorkloadName).AddArgument($ExcelCore).AddArgument($PPTTemplateFile).AddArgument($PPTFinalFile).AddArgument($CoreDebugging).AddArgument($Logfile).AddArgument($Heavy)


        if ($WordTemplateFile)
            {
            if ($CoreDebugging) { ('OfficeApps - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Setting Word Thread..') | Out-File -FilePath $LogFile -Append }
            $Word = ([PowerShell]::Create()).AddScript(
                {
                param($ResourcesTypes, $HighImpact, $MediumImpact, $LowImpact, $ServiceHighImpact, $WAFHighImpact, $ExcelContent, $Outages, $SupportTickets, $ServiceHealth, $Retirements, $Ex, $CustomerName, $WorkloadName, $ExcelCore, $WordTemplateFile, $WordFinalFile, $CoreDebugging, $Logfile, $Heavy)

                if ($CoreDebugging) { ('WordThread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Starting Word Thread..') | Out-File -FilePath $LogFile -Append }
                function Build-WordCore {
                    if ($CoreDebugging) { ('WordThread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Editing Word Core File..') | Out-File -FilePath $LogFile -Append }

                    try
                    {
                        $MatchCase = $false
                        $MatchWholeWord = $true
                        $MatchWildcards = $false
                        $MatchSoundsLike = $false
                        $MatchAllWordForms = $false
                        $Forward = $true
                        $wrap = $wdFindContinue
                        $wdFindContinue = 1
                        $Format = $false
                        $ReplaceAll = 2

                        if ($CoreDebugging) { ('WordThread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Replacing Workload name: ' + $WorkloadName) | Out-File -FilePath $LogFile -Append }
                        $FindText = '[Workload Name]'
                        $ReplaceWith = $WorkloadName
                        $Global:Document.Content.Find.Execute($FindText, $MatchCase, $MatchWholeWord, $MatchWildcards, $MatchSoundsLike, $MatchAllWordForms, $Forward, $wrap, $Format, $ReplaceWith, $ReplaceAll) | Out-Null
                        if ($Heavy) {Start-Sleep -Milliseconds 200}

                        $FindText = 'Workload Name'
                        $ReplaceWith = $WorkloadName
                        $Global:Document.Content.Find.Execute($FindText, $MatchCase, $MatchWholeWord, $MatchWildcards, $MatchSoundsLike, $MatchAllWordForms, $Forward, $wrap, $Format, $ReplaceWith, $ReplaceAll) | Out-Null
                        if ($Heavy) {Start-Sleep -Milliseconds 200}

                        if ($CoreDebugging) { ('WordThread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Replacing Customer name: ' + $CustomerName) | Out-File -FilePath $LogFile -Append }
                        $FindText = '[Customer Name]'
                        $ReplaceWith = $CustomerName
                        $Global:Document.Content.Find.Execute($FindText, $MatchCase, $MatchWholeWord, $MatchWildcards, $MatchSoundsLike, $MatchAllWordForms, $Forward, $wrap, $Format, $ReplaceWith, $ReplaceAll) | Out-Null
                        if ($Heavy) {Start-Sleep -Milliseconds 200}

                        $FindText = '[Type Customer Name Here]'
                        $ReplaceWith = $CustomerName
                        $Global:Document.Content.Find.Execute($FindText, $MatchCase, $MatchWholeWord, $MatchWildcards, $MatchSoundsLike, $MatchAllWordForms, $Forward, $wrap, $Format, $ReplaceWith, $ReplaceAll) | Out-Null
                        $Global:Document.Sections(1).Headers(1).Range.Find.Execute($FindText, $MatchCase, $MatchWholeWord, $MatchWildcards, $MatchSoundsLike, $MatchAllWordForms, $Forward, $wrap, $Format, $ReplaceWith, $ReplaceAll) | Out-Null
                        if ($Heavy) {Start-Sleep -Milliseconds 200}

                        # Total Recommendations
                        $Global:Document.Content.Paragraphs(145).Range.Text = [string]($ExcelCore | Where-Object { $_."Number of Impacted Resources?" -gt 0 }).count
                        if ($Heavy) {Start-Sleep -Milliseconds 100}
                        #High Impact
                        $Global:Document.Content.Paragraphs(155).Range.Text = [string]($ExcelCore | Where-Object { $_."Number of Impacted Resources?" -gt 0 -and $_.Impact -eq 'High' }).count
                        if ($Heavy) {Start-Sleep -Milliseconds 100}
                        #Medium Impact
                        $Global:Document.Content.Paragraphs(157).Range.Text = [string]($ExcelCore | Where-Object { $_."Number of Impacted Resources?" -gt 0 -and $_.Impact -eq 'Medium' }).count
                        if ($Heavy) {Start-Sleep -Milliseconds 100}
                        #Low Impact
                        $Global:Document.Content.Paragraphs(159).Range.Text = [string]($ExcelCore | Where-Object { $_."Number of Impacted Resources?" -gt 0 -and $_.Impact -eq 'Low' }).count
                        if ($Heavy) {Start-Sleep -Milliseconds 100}
                        #Impacted Resources
                        $Global:Document.Content.Paragraphs(165).Range.Text = [string]($ExcelContent.id | Where-Object { ![string]::IsNullOrEmpty($_) } | Select-Object -Unique).count
                        if ($Heavy) {Start-Sleep -Milliseconds 100}

                        $HealthHigh = $ExcelCore | Where-Object { $_."Number of Impacted Resources?" -gt 1 -and $_.Impact -eq 'High' } | Sort-Object -Property "Number of Impacted Resources?" -Descending

                        #Risk Assessment Result
                        $Global:Document.Content.Paragraphs(176).Range.Text = ''
                        $Global:Document.Content.Paragraphs(175).Range.Text = ''

                        #$Global:Document.Content.Paragraphs(158).Range.ListFormat.ApplyListTemplate($Global:Word.Application.ListGalleries[1].ListTemplates[3])

                        #Health Assessment Result
                        $Global:Document.Content.Paragraphs(172).Range.Text = ''

                        #$Global:Document.Content.Paragraphs(158).Range.ListFormat.ApplyListTemplate($Global:Word.Application.ListGalleries[1].ListTemplates[3])
                        $Global:Document.Content.Paragraphs(171).Range.Select()
                        $Loops = 1
                        Foreach ($Risk in $HealthHigh)
                        {
                            if ([string]::IsNullOrEmpty($Risk))
                            {
                                $Global:Document.Content.Paragraphs(171).Range.Text = ''
                            }
                            $Title = $Risk.'Recommendation Title'
                            if ($Loops -eq 1)
                            {
                                $Global:Word.Selection.TypeText($Title) | Out-Null
                            }
                            else
                            {
                                $Global:Word.Selection.TypeParagraph() | Out-Null
                                $Global:Word.Selection.TypeText($Title) | Out-Null
                            }
                            $Loops ++
                        }
                    }
                    catch
                    {
                        $errorMessage = $_.Exception
                        $ErrorStack = $_.ScriptStackTrace
                        if ($CoreDebugging) { ('WordThread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Error - ' + $errorMessage) | Out-File -FilePath $LogFile -Append }
                        if ($CoreDebugging) { ('WordThread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Error - ' + $ErrorStack) | Out-File -FilePath $LogFile -Append }
                    }
                }
                function Build-WordCharts {
                    if ($CoreDebugging) { ('WordThread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Editing Word Charts..') | Out-File -FilePath $LogFile -Append }

                    try
                    {
                        if ($CoreDebugging) { ('WordThread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Looking for Charts in the Excel file..') | Out-File -FilePath $LogFile -Append }
                        #Charts
                        $WS2 = $Global:Ex.Worksheets | Where-Object { $_.Name -eq 'Charts' }

                        $Position = $Global:Document.Content.Paragraphs(181).Range.Start

                        $Global:Document.Content.InlineShapes(10).Delete() | Out-Null
                        if ($Heavy) {Start-Sleep -Milliseconds 100}
                        $Global:Document.Content.InlineShapes(9).Delete() | Out-Null
                        if ($Heavy) {Start-Sleep -Milliseconds 100}
                        $Global:Document.Content.InlineShapes(8).Delete() | Out-Null
                        if ($Heavy) {Start-Sleep -Milliseconds 100}

                        if ($CoreDebugging) { ('WordThread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Coping Chart 1..') | Out-File -FilePath $LogFile -Append }
                        $WS2.ChartObjects('ChartP0').copy()

                        $Global:Document.Range($Position, $Position).Select()
                        $Global:Word.Selection.Paste() | Out-Null
                        if ($Heavy) {Start-Sleep -Milliseconds 200}

                        if ($CoreDebugging) { ('WordThread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Coping Chart 2..') | Out-File -FilePath $LogFile -Append }
                        $WS2.ChartObjects('ChartP1').copy()
                        $Global:Word.Selection.Paste() | Out-Null
                        if ($Heavy) {Start-Sleep -Milliseconds 200}
                    }
                    catch
                    {
                        $errorMessage = $_.Exception
                        $ErrorStack = $_.ScriptStackTrace
                        if ($CoreDebugging) { ('WordThread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Error - ' + $errorMessage) | Out-File -FilePath $LogFile -Append }
                        if ($CoreDebugging) { ('WordThread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Error - ' + $ErrorStack) | Out-File -FilePath $LogFile -Append }
                    }
                }
                function Build-WordOutages {
                    if ($CoreDebugging) { ('WordThread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Editing Outages..') | Out-File -FilePath $LogFile -Append }

                    try
                    {
                        $Global:Document.Tables(10).Rows(2).Cells(1).Range.Text = ''
                        $Global:Document.Tables(10).Rows(2).Cells(2).Range.Text = ''
                        $Global:Document.Tables(10).Rows(2).Cells(3).Range.Text = ''

                        $LineCounter = 2
                        if (![string]::IsNullOrEmpty($Global:Outages))
                        {
                            if ($CoreDebugging) { ('WordThread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Outages found..') | Out-File -FilePath $LogFile -Append }
                            foreach ($Outage in $Global:Outages)
                            {
                                if ($LineCounter -gt 3)
                                {
                                    $Global:Document.Tables(10).Rows.Add() | Out-Null
                                    if ($Heavy) {Start-Sleep -Milliseconds 100}
                                }
                                $OutageName = ($Outage.'Tracking ID' + ' - ' + $Outage.title)
                                if ($CoreDebugging) { ('WordThread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Adding Outage: ' + $OutageName) | Out-File -FilePath $LogFile -Append }
                                $OutageWhat = $Outage.'What happened'
                                $OutageRecom = $Outage.'How can customers make incidents like this less impactful'

                                $Global:Document.Tables(10).Rows($LineCounter).Cells(1).Range.Text = $OutageName
                                $Global:Document.Tables(10).Rows($LineCounter).Cells(2).Range.Text = $OutageWhat
                                $Global:Document.Tables(10).Rows($LineCounter).Cells(3).Range.Text = $OutageRecom

                                $LineCounter ++
                            }
                        }
                    }
                    catch
                    {
                        $errorMessage = $_.Exception
                        $ErrorStack = $_.ScriptStackTrace
                        if ($CoreDebugging) { ('WordThread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Error - ' + $errorMessage) | Out-File -FilePath $LogFile -Append }
                        if ($CoreDebugging) { ('WordThread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Error - ' + $ErrorStack) | Out-File -FilePath $LogFile -Append }
                    }
                }
                function Build-WordTables {
                    if ($CoreDebugging) { ('WordThread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Editing Tables..') | Out-File -FilePath $LogFile -Append }

                    try
                    {
                        if ($CoreDebugging) { ('WordThread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Cleaning Table 6..') | Out-File -FilePath $LogFile -Append }
                        $row = 2
                        while ($row -lt 5)
                        {
                            $cell = 1
                            while ($cell -lt 5)
                            {
                                $Global:Document.Tables(6).Rows($row).Cells($cell).Range.Text = ''
                                $Cell ++
                            }
                            $row ++
                        }

                        if ($CoreDebugging) { ('WordThread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Cleaning Table 7..') | Out-File -FilePath $LogFile -Append }
                        $row = 2
                        while ($row -lt 3)
                        {
                            $cell = 1
                            while ($cell -lt 5)
                            {
                                $Global:Document.Tables(7).Rows($row).Cells($cell).Range.Text = ''
                                $Cell ++
                            }
                            $row ++
                        }

                        if ($CoreDebugging) { ('WordThread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Cleaning Table 8..') | Out-File -FilePath $LogFile -Append }
                        $row = 2
                        while ($row -lt 3)
                        {
                            $cell = 1
                            while ($cell -lt 5)
                            {
                                $Global:Document.Tables(8).Rows($row).Cells($cell).Range.Text = ''
                                $Cell ++
                            }
                            $row ++
                        }

                        #Populate Table Health and Risk Summary High
                        $counter = 1
                        $row = 2
                        foreach ($Impact in $HighImpact)
                        {
                            $LogHighImpact = $Impact.'Recommendation Title'
                            if ($CoreDebugging) { ('WordThread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Adding High Impact: ' + $LogHighImpact) | Out-File -FilePath $LogFile -Append }
                            if ($counter -lt 14)
                            {
                                #Number
                                $Global:Document.Tables(6).Rows($row).Cells(1).Range.Text = [string]$counter
                                #Recommendation
                                $Global:Document.Tables(6).Rows($row).Cells(2).Range.Text = $Impact.'Recommendation Title'
                                #Service
                                if ($Impact.'Azure Service / Well-Architected' -eq 'Well Architected') {
                                $ServiceName = ('WAF - ' + $Impact.'Azure Service / Well-Architected Topic')
                                }
                                else {
                                $ServiceName = $Impact.'Azure Service / Well-Architected Topic'
                                }
                                $Global:Document.Tables(6).Rows($row).Cells(3).Range.Text = $ServiceName
                                #Impacted Resources
                                $Global:Document.Tables(6).Rows($row).Cells(4).Range.Text = [string]$Impact.'Number of Impacted Resources?'
                                $counter ++
                                $row ++
                                if ($Heavy) {Start-Sleep -Milliseconds 100}
                            }
                            else
                            {
                                if ($CoreDebugging) { ('WordThread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Adding Row to High Impact table..') | Out-File -FilePath $LogFile -Append }
                                $Global:Document.Tables(6).Rows.add() | Out-Null
                                #Number
                                $Global:Document.Tables(6).Rows($row).Cells(1).Range.Text = [string]$counter
                                #Recommendation
                                $Global:Document.Tables(6).Rows($row).Cells(2).Range.Text = $Impact.'Recommendation Title'
                                #Service
                                if ($Impact.'Azure Service / Well-Architected' -eq 'Well Architected')
                                {
                                    $ServiceName = ('WAF - ' + $Impact.'Azure Service / Well-Architected Topic')
                                }
                                else
                                {
                                    $ServiceName = $Impact.'Azure Service / Well-Architected Topic'
                                }
                                $Global:Document.Tables(6).Rows($row).Cells(3).Range.Text = $ServiceName
                                #Impacted Resources
                                $Global:Document.Tables(6).Rows($row).Cells(4).Range.Text = [string]$Impact.'Number of Impacted Resources?'
                                $counter ++
                                $row ++
                                if ($Heavy) {Start-Sleep -Milliseconds 100}
                            }
                        }

                        #Populate Table Health and Risk Summary Medium
                        $counter = 1
                        $row = 2
                        foreach ($Impact in $MediumImpact)
                        {
                            $LogMediumImpact = $Impact.'Recommendation Title'
                            if ($CoreDebugging) { ('WordThread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Adding Medium Impact: ' + $LogMediumImpact) | Out-File -FilePath $LogFile -Append }
                            if ($counter -lt 14)
                            {
                                #Number
                                $Global:Document.Tables(7).Rows($row).Cells(1).Range.Text = [string]$counter
                                #Recommendation
                                $Global:Document.Tables(7).Rows($row).Cells(2).Range.Text = $Impact.'Recommendation Title'
                                #Service
                                if ($Impact.'Azure Service / Well-Architected' -eq 'Well Architected')
                                {
                                    $ServiceName = ('WAF - ' + $Impact.'Azure Service / Well-Architected Topic')
                                }
                                else
                                {
                                    $ServiceName = $Impact.'Azure Service / Well-Architected Topic'
                                }
                                $Global:Document.Tables(7).Rows($row).Cells(3).Range.Text = $ServiceName
                                #Impacted Resources
                                $Global:Document.Tables(7).Rows($row).Cells(4).Range.Text = [string]$Impact.'Number of Impacted Resources?'
                                $counter ++
                                $row ++
                                if ($Heavy) {Start-Sleep -Milliseconds 100}
                            }
                            else
                            {
                                if ($CoreDebugging) { ('WordThread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Adding Row to Medium Impact table..') | Out-File -FilePath $LogFile -Append }
                                $Global:Document.Tables(7).Rows.add() | Out-Null
                                #Number
                                $Global:Document.Tables(7).Rows($row).Cells(1).Range.Text = [string]$counter
                                #Recommendation
                                $Global:Document.Tables(7).Rows($row).Cells(2).Range.Text = $Impact.'Recommendation Title'
                                #Service
                                if ($Impact.'Azure Service / Well-Architected' -eq 'Well Architected')
                                {
                                    $ServiceName = ('WAF - ' + $Impact.'Azure Service / Well-Architected Topic')
                                }
                                else
                                {
                                    $ServiceName = $Impact.'Azure Service / Well-Architected Topic'
                                }
                                $Global:Document.Tables(7).Rows($row).Cells(3).Range.Text = $ServiceName
                                #Impacted Resources
                                $Global:Document.Tables(7).Rows($row).Cells(4).Range.Text = [string]$Impact.'Number of Impacted Resources?'
                                $counter ++
                                $row ++
                                if ($Heavy) {Start-Sleep -Milliseconds 100}
                            }
                        }

                        #Populate Table Health and Risk Summary Low
                        $counter = 1
                        $row = 2
                        foreach ($Impact in $LowImpact)
                        {
                            $LogLowImpact = $Impact.'Recommendation Title'
                            if ($CoreDebugging) { ('WordThread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Adding Low Impact: ' + $LogLowImpact) | Out-File -FilePath $LogFile -Append }
                            if ($counter -lt 14)
                            {
                                #Number
                                $Global:Document.Tables(8).Rows($row).Cells(1).Range.Text = [string]$counter
                                #Recommendation
                                $Global:Document.Tables(8).Rows($row).Cells(2).Range.Text = $Impact.'Recommendation Title'
                                #Service
                                if ($Impact.'Azure Service / Well-Architected' -eq 'Well Architected')
                                {
                                    $ServiceName = ('WAF - ' + $Impact.'Azure Service / Well-Architected Topic')
                                }
                                else
                                {
                                    $ServiceName = $Impact.'Azure Service / Well-Architected Topic'
                                }
                                $Global:Document.Tables(8).Rows($row).Cells(3).Range.Text = $ServiceName
                                #Impacted Resources
                                $Global:Document.Tables(8).Rows($row).Cells(4).Range.Text = [string]$Impact.'Number of Impacted Resources?'
                                $counter ++
                                $row ++
                                if ($Heavy) {Start-Sleep -Milliseconds 100}
                            }
                            else
                            {
                                if ($CoreDebugging) { ('WordThread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Adding Row to Low Impact table..') | Out-File -FilePath $LogFile -Append }
                                $Global:Document.Tables(8).Rows.add() | Out-Null
                                #Number
                                $Global:Document.Tables(8).Rows($row).Cells(1).Range.Text = [string]$counter
                                #Recommendation
                                $Global:Document.Tables(8).Rows($row).Cells(2).Range.Text = $Impact.'Recommendation Title'
                                #Service
                                if ($Impact.'Azure Service / Well-Architected' -eq 'Well Architected')
                                {
                                    $ServiceName = ('WAF - ' + $Impact.'Azure Service / Well-Architected Topic')
                                }
                                else
                                {
                                    $ServiceName = $Impact.'Azure Service / Well-Architected Topic'
                                }
                                $Global:Document.Tables(8).Rows($row).Cells(3).Range.Text = $ServiceName
                                #Impacted Resources
                                $Global:Document.Tables(8).Rows($row).Cells(4).Range.Text = [string]$Impact.'Number of Impacted Resources?'
                                $counter ++
                                $row ++
                                if ($Heavy) {Start-Sleep -Milliseconds 100}
                            }
                        }
                    }
                    catch
                    {
                        $errorMessage = $_.Exception
                        $ErrorStack = $_.ScriptStackTrace
                        if ($CoreDebugging) { ('WordThread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Error - ' + $errorMessage) | Out-File -FilePath $LogFile -Append }
                        if ($CoreDebugging) { ('WordThread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Error - ' + $ErrorStack) | Out-File -FilePath $LogFile -Append }
                    }
                }
                function Build-WordRetirements {
                    if ($CoreDebugging) { ('WordThread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Editing Retirements..') | Out-File -FilePath $LogFile -Append }

                    try
                    {
                        $Global:Document.Tables(12).Rows(2).Cells(1).Range.Text = ''
                        $Global:Document.Tables(12).Rows(2).Cells(2).Range.Text = ''
                        $Global:Document.Tables(12).Rows(2).Cells(3).Range.Text = ''

                        $LineCounter = 2
                        if (![string]::IsNullOrEmpty($Global:Retirements))
                        {
                            if ($CoreDebugging) { ('WordThread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Retirements found..') | Out-File -FilePath $LogFile -Append }
                            foreach ($Retires in $Global:Retirements)
                            {
                                if ($LineCounter -gt 3)
                                {
                                    $Global:Document.Tables(12).Rows.Add() | Out-Null
                                }
                                $RetireName = ($Retires.'Tracking ID' + ' - ' + $Retires.Status + ' : ' + $Retires.title)
                                if ($CoreDebugging) { ('WordThread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Adding Retirement: ' + $RetireName) | Out-File -FilePath $LogFile -Append }
                                $RetireSub = $Retires.Subscription
                                $RetireDetails = $Retires.Details

                                $Global:Document.Tables(12).Rows($LineCounter).Cells(1).Range.Text = $RetireName
                                $Global:Document.Tables(12).Rows($LineCounter).Cells(2).Range.Text = $RetireSub
                                $Global:Document.Tables(12).Rows($LineCounter).Cells(3).Range.Text = $RetireDetails

                                $LineCounter ++
                                if ($Heavy) {Start-Sleep -Milliseconds 100}
                            }
                        }
                    }
                    catch
                    {
                        $errorMessage = $_.Exception
                        $ErrorStack = $_.ScriptStackTrace
                        if ($CoreDebugging) { ('WordThread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Error - ' + $errorMessage) | Out-File -FilePath $LogFile -Append }
                        if ($CoreDebugging) { ('WordThread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Error - ' + $ErrorStack) | Out-File -FilePath $LogFile -Append }
                    }
                }
                function Build-WordSupports {
                    if ($CoreDebugging) { ('WordThread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Editing Support Tickets..') | Out-File -FilePath $LogFile -Append }

                    try
                    {
                        $Global:Document.Tables(11).Rows(2).Cells(1).Range.Text = ''
                        $Global:Document.Tables(11).Rows(2).Cells(2).Range.Text = ''
                        $Global:Document.Tables(11).Rows(2).Cells(3).Range.Text = ''
                        $Global:Document.Tables(11).Rows(2).Cells(4).Range.Text = ''

                        $LineCounter = 2
                        if (![string]::IsNullOrEmpty($Global:SupportTickets))
                        {
                            if ($CoreDebugging) { ('WordThread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Support Tickets found..') | Out-File -FilePath $LogFile -Append }
                            foreach ($Ticket in $Global:SupportTickets)
                            {
                                if ($LineCounter -gt 3)
                                {
                                    $Global:Document.Tables(11).Rows.Add() | Out-Null
                                }
                                $TicketName = ($Ticket.'Ticket ID' + ' - ' + $Ticket.Title)
                                if ($CoreDebugging) { ('WordThread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Adding Support Ticket: ' + $TicketName) | Out-File -FilePath $LogFile -Append }
                                $CreatedDate = $Ticket.'Creation Date'

                                $Global:Document.Tables(11).Rows($LineCounter).Cells(1).Range.Text = $TicketName
                                $Global:Document.Tables(11).Rows($LineCounter).Cells(2).Range.Text = $CreatedDate
                                $Global:Document.Tables(11).Rows($LineCounter).Cells(3).Range.Text = " "
                                $Global:Document.Tables(11).Rows($LineCounter).Cells(4).Range.Text = " "

                                $LineCounter ++
                                if ($Heavy) {Start-Sleep -Milliseconds 100}
                            }
                        }
                    }
                    catch
                    {
                        $errorMessage = $_.Exception
                        $ErrorStack = $_.ScriptStackTrace
                        if ($CoreDebugging) { ('WordThread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Error - ' + $errorMessage) | Out-File -FilePath $LogFile -Append }
                        if ($CoreDebugging) { ('WordThread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Error - ' + $ErrorStack) | Out-File -FilePath $LogFile -Append }
                    }
                }
                function Build-WordHealths {
                    if ($CoreDebugging) { ('WordThread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Editing Service Health Alerts..') | Out-File -FilePath $LogFile -Append }

                    try
                    {
                        $Global:Document.Tables(5).Rows(3).Cells(1).Range.Text = ''
                        $Global:Document.Tables(5).Rows(3).Cells(2).Range.Text = ''
                        $Global:Document.Tables(5).Rows(3).Cells(3).Range.Text = ''
                        $Global:Document.Tables(5).Rows(3).Cells(4).Range.Text = ''
                        $Global:Document.Tables(5).Rows(3).Cells(5).Range.Text = ''
                        $Global:Document.Tables(5).Rows(3).Cells(6).Range.Text = ''
                        $Global:Document.Tables(5).Rows(3).Cells(7).Range.Text = ''
                        $Global:Document.Tables(5).Rows(3).Cells(8).Range.Text = ''

                        $LineCounter = 3
                        if (![string]::IsNullOrEmpty($Global:ServiceHealth))
                        {
                            if ($CoreDebugging) { ('WordThread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Service Health Alerts found..') | Out-File -FilePath $LogFile -Append }
                            foreach ($Health in $Global:ServiceHealth)
                            {
                                $LogHealthName = $Health.Name
                                if ($CoreDebugging) { ('WordThread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Adding Service Health Alert: ' + $LogHealthName) | Out-File -FilePath $LogFile -Append }
                                if ($LineCounter -gt 4)
                                {
                                    $Global:Document.Tables(5).Rows.Add() | Out-Null
                                }
                                $ActionGroup = $Health.'Action Group'

                                $Global:Document.Tables(5).Rows($LineCounter).Cells(1).Range.Text = $Health.Subscription
                                $Global:Document.Tables(5).Rows($LineCounter).Cells(2).Range.Text = $Health.Services
                                $Global:Document.Tables(5).Rows($LineCounter).Cells(3).Range.Text = $Health.Regions
                                $Global:Document.Tables(5).Rows($LineCounter).Cells(4).Range.Text = if ($Health.'Event Type' -like '*Service Issues*' -or $Health.'Event Type' -eq 'All') { 'Yes' }else { 'No' }
                                $Global:Document.Tables(5).Rows($LineCounter).Cells(5).Range.Text = if ($Health.'Event Type' -like '*Planned Maintenance*' -or $Health.'Event Type' -eq 'All') { 'Yes' }else { 'No' }
                                $Global:Document.Tables(5).Rows($LineCounter).Cells(6).Range.Text = if ($Health.'Event Type' -like '*Health Advisories*' -or $Health.'Event Type' -eq 'All') { 'Yes' }else { 'No' }
                                $Global:Document.Tables(5).Rows($LineCounter).Cells(7).Range.Text = if ($Health.'Event Type' -like '*Security Advisory*' -or $Health.'Event Type' -eq 'All') { 'Yes' }else { 'No' }
                                $Global:Document.Tables(5).Rows($LineCounter).Cells(8).Range.Text = $ActionGroup
                                $LineCounter ++
                                if ($Heavy) {Start-Sleep -Milliseconds 100}
                            }
                        }
                    }
                    catch
                    {
                        $errorMessage = $_.Exception
                        $ErrorStack = $_.ScriptStackTrace
                        if ($CoreDebugging) { ('WordThread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Error - ' + $errorMessage) | Out-File -FilePath $LogFile -Append }
                        if ($CoreDebugging) { ('WordThread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Error - ' + $ErrorStack) | Out-File -FilePath $LogFile -Append }
                    }
                }

                if ($CoreDebugging) { ('WordThread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Starting Word..') | Out-File -FilePath $LogFile -Append }
                try
                    {
                    $Global:Word = New-Object -Com Word.Application

                    $Global:Document = $Word.documents.open($WordTemplateFile)

                    Build-WordCharts
                    Build-WordCore
                    Build-WordRetirements
                    Build-WordSupports
                    Build-WordOutages
                    Build-WordTables
                    Build-WordHealths

                    if ($CoreDebugging) { ('WordThread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Closing Word..') | Out-File -FilePath $LogFile -Append }
                    $Global:Document.SaveAs($WordFinalFile)
                    if ($Heavy) {Start-Sleep -Milliseconds 200}
                    $Global:Document.Close()
                    $Global:Word.Quit()
                    }
                catch
                    {
                    $errorMessage = $_.Exception
                    $ErrorStack = $_.ScriptStackTrace
                    if ($CoreDebugging) { ('WordThread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Error - ' + $errorMessage) | Out-File -FilePath $LogFile -Append }
                    if ($CoreDebugging) { ('WordThread - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Error - ' + $ErrorStack) | Out-File -FilePath $LogFile -Append }
                    }

                }).AddArgument($ResourcesTypes).AddArgument($HighImpact).AddArgument($MediumImpact).AddArgument($LowImpact).AddArgument($ServiceHighImpact).AddArgument($WAFHighImpact).AddArgument($ExcelContent).AddArgument($Outages).AddArgument($SupportTickets).AddArgument($ServiceHealth).AddArgument($Retirements).AddArgument($Ex).AddArgument($CustomerName).AddArgument($WorkloadName).AddArgument($ExcelCore).AddArgument($WordTemplateFile).AddArgument($WordFinalFile).AddArgument($CoreDebugging).AddArgument($Logfile).AddArgument($Heavy)
            }

        try
            {
            if ($CoreDebugging) { ('OfficeApps - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Invoking PPT Thread..') | Out-File -FilePath $LogFile -Append }
            $jobPPT = $PPT.BeginInvoke()
            if ($WordTemplateFile)
                {
                if ($CoreDebugging) { ('OfficeApps - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Invoking Word Thread..') | Out-File -FilePath $LogFile -Append }
                $jobWord = $Word.BeginInvoke()
                }

            $job += $jobPPT
            if ($WordTemplateFile)
                {
                $job += $jobWord
                }

            if ($CoreDebugging) { ('OfficeApps - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Waiting Threads..') | Out-File -FilePath $LogFile -Append }
            while ($Job.Runspace.IsCompleted -contains $false) {}

            if ($CoreDebugging) { ('OfficeApps - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Finishing Threads..') | Out-File -FilePath $LogFile -Append }
            $PPT.EndInvoke($jobPPT)
            if ($WordTemplateFile)
                {
                $Word.EndInvoke($jobWord)
                }

            if ($CoreDebugging) { ('OfficeApps - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Disposing Threads..') | Out-File -FilePath $LogFile -Append }
            $PPT.Dispose()
            if ($WordTemplateFile)
                {
                $Word.Dispose()
                }
            }
        catch
            {
            $errorMessage = $_.Exception
            $ErrorStack = $_.ScriptStackTrace
            if ($CoreDebugging) { ('OfficeApps - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Error - ' + $errorMessage) | Out-File -FilePath $LogFile -Append }
            if ($CoreDebugging) { ('OfficeApps - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Error - ' + $ErrorStack) | Out-File -FilePath $LogFile -Append }
            }

        if ($CoreDebugging) { ('OfficeApps - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Closing Excel..') | Out-File -FilePath $LogFile -Append }
        try
            {
            $Global:Ex.Save()
            $Global:Ex.Close()
            $Global:ExcelApplication.Quit()
            }
        catch
            {
            $errorMessage = $_.Exception
            $ErrorStack = $_.ScriptStackTrace
            if ($CoreDebugging) { ('OfficeApps - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Error - ' + $errorMessage) | Out-File -FilePath $LogFile -Append }
            if ($CoreDebugging) { ('OfficeApps - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Error - ' + $ErrorStack) | Out-File -FilePath $LogFile -Append }
            }

        } -ArgumentList $Global:ExcelCore, $Global:ExcelContent, $Global:Outages, $Global:SupportTickets, $Global:ServiceHealth, $Global:Retirements, $ExcelFile, $CustomerName, $WorkloadName, $PPTTemplateFile, $Global:PPTFinalFile, $WordTemplateFile, $Global:WordFinalFile, $Global:CoreDebugging, $Global:LogFile, $Global:Heavy
    }
    function Build-SummaryActionPlan {
    Param($ExcelContent,$ExcelRecommendations,$includeLow)

    $Recommendations = $ExcelContent | Where-Object {$_.impact -in ('High','Medium','Low')}

<#     if ($includeLow.IsPresent)
        {
        $Recommendations = $ExcelContent | Where-Object {$_.impact -in ('High','Medium','Low')}
        }
    else
        {
        $Recommendations = $ExcelContent | Where-Object {$_.impact -in ('High','Medium')}
        } #>

    $RecomCount = ($Recommendations.recommendationId | Select-Object -Unique).count
    if ($Debugging.IsPresent) { ('CSVProcess - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Creating CSV file for: '+$RecomCount+' recommendations') | Out-File -FilePath $LogFile -Append }

    $CXSummaryArray = Foreach ($Recommendation in $Recommendations)
        {
        $Description = $ExcelRecommendations | Where-Object {$_.'Recommendation Id' -eq $Recommendation.recommendationId}
        $tmp = [PSCustomObject]@{
            'Recommendation Guid'       = $Recommendation.recommendationId
            'Recommendation Title'      = $Recommendation.recommendationTitle
            'Priority'                  = $Recommendation.impact
            'Potential Benefits'        = $Description.'Potential Benefits'
            'Description'               = $Description.'Best Practices Guidance'
            'Resource ID'               = $Recommendation.id
            'Customer-facing annotation'= ''
            'Internal-facing note'      = ''
        }
        $tmp
        }

    return $CXSummaryArray

    }

    #Call the functions
    $Global:LogFile = ($PSScriptRoot + '\wara_reports_generator.log')
    $Global:Version = "2.1.7"
    Write-Host "Version: " -NoNewline
    Write-Host $Global:Version -ForegroundColor DarkBlue -NoNewline
    Write-Host " "

    if ($Debugging.IsPresent) { (' ---------------------------------- STARTING REPORT GENERATOR SCRIPT --------------------------------------- ') | Out-File -FilePath $LogFile -Append }
    if ($Debugging.IsPresent) { ('RootProces - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Starting Report Generator Script..') | Out-File -FilePath $LogFile -Append }
    if ($Debugging.IsPresent) { ('RootProces - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Script Version: ' + $Global:Version) | Out-File -FilePath $LogFile -Append }
    if ($Debugging.IsPresent) { ('RootProces - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Excel File: ' + $ExcelFile) | Out-File -FilePath $LogFile -Append }
    if ($Debugging.IsPresent)
        {
        $ImportExcel = Get-Module -Name ImportExcel -ListAvailable -ErrorAction silentlycontinue
        foreach ($IExcel in $ImportExcel)
            {
            $IExcelPath = $IExcel.Path
            $IExcelVer = [string]$IExcel.Version
            ('RootProces - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - ImportExcel Module Path: ' + $IExcelPath) | Out-File -FilePath $LogFile -Append
            ('RootProces - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - ImportExcel Module Version: ' + $IExcelVer) | Out-File -FilePath $LogFile -Append
            }
        }

    if ($Help.IsPresent)
        {
        if ($Debugging.IsPresent) { ('RootProces - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Help menu invoked..') | Out-File -FilePath $LogFile -Append }
        Get-HelpMessage
        Exit
        }

    Write-Progress -Id 1 -activity "Processing Office Apps" -Status "10% Complete." -PercentComplete 10

    Test-Requirement

    if ($Global:Heavy) {Start-Sleep -Milliseconds 20}
    Write-Progress -Id 1 -activity "Processing Office Apps" -Status "15% Complete." -PercentComplete 15

    Set-LocalFolder

    if ($Global:Heavy) {Start-Sleep -Milliseconds 20}
    Write-Progress -Id 1 -activity "Processing Office Apps" -Status "20% Complete." -PercentComplete 20

    Get-Excel

    if ($Global:Heavy) {Start-Sleep -Milliseconds 20}

    #Test-Excel -ExcelContent $Global:ExcelContent -byPassValidationStatus $byPassValidationStatus

    Write-Host "Editing " -NoNewline
    $Global:PPTFinalFile = ($PSScriptRoot + '\Executive Summary Presentation - ' + $CustomerName + ' - ' + (get-date -Format "yyyy-MM-dd-HH-mm") + '.pptx')
    if ($WordTemplateFile)
        {
        Write-Host "PowerPoint" -ForegroundColor DarkRed -NoNewline
        Write-Host " and " -NoNewline
        Write-Host "Word" -ForegroundColor DarkBlue -NoNewline
        Write-Host " "
        $Global:WordFinalFile = ($PSScriptRoot + '\Assessment Report - ' + $CustomerName + ' - ' + (get-date -Format "yyyy-MM-dd-HH-mm") + '.docx')
        }
    else
        {
        Write-Host "PowerPoint" -ForegroundColor DarkRed -NoNewline
        Write-Host " "
        }

    if ($Debugging.IsPresent) { ('RootProces - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Calling Orchestrator function..') | Out-File -FilePath $LogFile -Append }
    Invoke-Orchestrator
    if ($Global:Heavy) {Start-Sleep -Milliseconds 100}

    if ($Debugging.IsPresent) { ('RootProces - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Waiting for OfficeApps Job..') | Out-File -FilePath $LogFile -Append }
    while (Get-Job -Name 'OfficeApps' | Where-Object { $_.State -eq 'Running' })
        {
        Write-Progress -Id 1 -activity "Processing Office Apps" -Status "60% Complete." -PercentComplete 60
        Start-Sleep -Seconds 2
        }
    Write-Progress -Id 1 -activity "Processing Office Apps" -Status "80% Complete." -PercentComplete 80

    Get-Job -Name 'OfficeApps' | Remove-Job

    if ($Debugging.IsPresent) { ('RootProces - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Trying to kill PowerPoint process.') }
    Get-Process -Name "POWERPNT" -ErrorAction Ignore | Where-Object { $_.CommandLine -like '*/automation*' } | Stop-Process
    if ($WordTemplateFile)
        {
        if ($Debugging.IsPresent) { ('RootProces - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Trying to kill Word process..') | Out-File -FilePath $LogFile -Append }
        Get-Process -Name "WINWORD" -ErrorAction Ignore | Where-Object { $_.CommandLine -like '*/automation*' } | Stop-Process
        }
    if ($Debugging.IsPresent) { ('RootProces - ' + (get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Info - Trying to kill Excel process..') | Out-File -FilePath $LogFile -Append }
    Get-Process -Name "excel" -ErrorAction Ignore | Where-Object { $_.CommandLine -like '*/automation*' } | Stop-Process

    Write-Progress -Id 1 -activity "Processing Office Apps" -Status "90% Complete." -PercentComplete 90
    }

<#     if($GenerateCSV.IsPresent)
    {
        $WorkloadRecommendationTemplate = Build-SummaryActionPlan -ExcelContent $ExcelContent -ExcelRecommendations $ExcelRecommendations -includeLow $includeLow

        $CSVFile = ($PSScriptRoot + '\Impacted Resources and Recommendations Template ' + (get-date -Format "yyyy-MM-dd-HH-mm") + '.csv')

        $WorkloadRecommendationTemplate | Export-Csv -Path $CSVFile
    } #>

    Write-Progress -Id 1 -activity "Processing Office Apps" -Status "100% Complete." -Completed
    $TotalTime = $Global:Runtime.Totalminutes.ToString('#######.##')

    ################ Finishing

    if ($Debugging.IsPresent) {Write-Debug "Debugging Log File: $Global:LogFile"}
    Write-Host "---------------------------------------------------------------------"
    Write-Host ('Execution Complete. Total Runtime was: ') -NoNewline
    Write-Host $TotalTime -NoNewline -ForegroundColor Cyan
    Write-Host (' Minutes')
    Write-Host 'PowerPoint File Saved As: ' -NoNewline
    Write-Host $PPTFinalFile -ForegroundColor Cyan
    if ($WordTemplateFile)
    {
        Write-Host 'Word File Saved As: ' -NoNewline
        Write-Host $WordFinalFile -ForegroundColor Cyan
    }
    if ($GenerateCSV.IsPresent)
    {
        Write-Host 'CSV File Saved as: ' -NoNewline
        Write-Host $CSVFile -ForegroundColor Cyan
    }

    Write-Host "---------------------------------------------------------------------"
