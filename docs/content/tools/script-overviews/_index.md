---
title: Overview and Usage of APRL Scripts
weight: 10
geekdocCollapseSection: false
---

This section provides an overview of the Azure Proactive Resiliency Library v2 (APRL) scripts and how to use them. The following scenarios are covered:

{{< toc >}}

## 1 - Collector Script

- [GitHub Link to Download](https://github.com/Azure/Azure-Proactive-Resiliency-Library-v2/blob/main/tools/1_wara_collector.ps1)
- Download the script using command-line
    ```shell
    iwr https://aka.ms/aprl/tools/1 -out 1_wara_collector.ps1
    ```
- [GitHub Link to Sample Output](https://github.com/Azure/Azure-Proactive-Resiliency-Library-v2/blob/main/tools/sample-output/WARA_File_2024-05-07_11_59.json)

The Collector PowerShell script is the first script to be run in the Azure Proactive Resiliency Library (APRL) tooling suite. It is designed to collect data from the Azure environment to help identify potential issues and areas for improvement using the Azure Resource Graph queries within this repository. The script leverages the Az.ResourceGraph module to query Azure Resource Graph for relevant data.

---

**You have two options for running the collector script:**

1. Cloud Shell - Requires Cloud Shell be configured with write access to a fileshare within the same tenant

1. Local Machine - Requires current modules leveraged in the script be installed

### 1.1 - Cloud Shell

1. From the [Azure Portal](https://portal.azure.com/) open Cloud Shell, select PowerShell instead of BASH

    - If this is your first time using Cloud Shell, refer to the getting started guide from Microsoft Learn - [Azure Cloud Shell](https://learn.microsoft.com/en-us/azure/cloud-shell/get-started/classic?tabs=azurecli#start-cloud-shell).

    {{< figure src="../../img/tools/collector-1.png" width="100%" >}}

1. Upload the WARA Collector Script to Cloud Shell
  {{< figure src="../../img/tools/collector-2.png" width="60%" >}}

    Or download the script from GtiHub

    ```shell
    iwr https://aka.ms/aprl/tools/1 -out 1_wara_collector.ps1
    ```

1. Execute script leveraging optional parameters

    - Parameters include:
      - **TenantID**:  *Optional* ; tenant to be used.
      - **SubscriptionIds**:  *Required (or ConfigFile)* ; Specifies Subscription(s) to be included in the analysis: /subscriptions/YYYYYYYY-YYYY-YYYY-YYYY-YYYYYYYYYYYY,/subscriptions/AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA.
      - **RunbookFile**:  *Optional* ; specifies the file with the runbook (selectors & checks) to be used.
      - **ResourceGroups**:  *Optional* ; specifies Resource Group(s) to be included in the analysis: /subscriptions/YYYYYYYY-YYYY-YYYY-YYYY-YYYYYYYYYYYY/resourceGroups/ResourceGroup1,/subscriptions/YYYYYYYY-YYYY-YYYY-YYYY-YYYYYYYYYYYY/resourceGroups/ResourceGroup2.
      - **Tags**:  *Optional* ; specifies tags to be used for filtering the resources: TagName1||TagName2||TagNameN==TagValue1||TagValue2, TagName1==TagValue1.
      - **ConfigFile**:  *Optional* ; specifies a file for advanced filtering, including: subscription, resourceGroup, resourceId, Tags.
      - **AzureEnvironment**:  *Optional* ; specifies the Azure Environment to used for the analysis: AzureCloud, AzureUSGovernment.
      - **SAP**:  *Optional* ; used for specialized workload analysis.
      - **AVD**:  *Optional* ; used for specialized workload analysis.
      - **AVS**:  *Optional* ; used for specialized workload analysis.
      - **HPC**:  *Optional* ; used for specialized workload analysis.
      - **Debugging**: *Optional* ; Writes Debugging information of the script during the execution.

    {{< figure src="../../img/tools/collector-3.png" width="100%" >}}

1. Select "A" to allow modules to install
  {{< figure src="../../img/tools/collector-4.png" width="100%" >}}

1. After Script completes, download the results
  {{< figure src="../../img/tools/collector-5.png" width="100%" >}}

### 1.2 Local Machine

1. To run the script there are 5 prerequisites that must be completed first:
    1. **The script must be executed from PowerShell 7, not Windows PowerShell or PowerShell ISE.**
      {{< figure src="../../img/tools/collector-6.png" width="40%" >}}
    1. **Git must be installed on the local machine - [Git](https://git-scm.com/download/win)**
    1. **Install required PowerShell Modules:**
        - Install-Module -Name ImportExcel -Force -SkipPublisherCheck
        - Install-Module -Name Az.ResourceGraph -SkipPublisherCheck
        - Install-Module -Name Az.Accounts -SkipPublisherCheck
    1. **Unblock the Script**
        - The script is digitally signed, but the PowerShell module ImportExcel is not. So at this moment, you need to allow the execution of scripts not signed locally:
          - Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope CurrentUser
          - Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope LocalMachine
    1. **Reader permissions to target subscription(s)**

1. Open a new PowerShell 7 session after completeing prerequisites

1. Change your directory to the same location that you have downloaded the WARA collector script to.

    - We recommend running this as close to your C:\ as path to avoid errors related to file path length.
    {{< figure src="../../img/tools/collector-7.png" width="40%" >}}

1. Execute script leveraging optional parameters

      - Parameters include:
        - **TenantID**:  *Optional* ; tenant to be used.
        - **SubscriptionIds**:  *Optional if ResourceGroup(s) are provided or a ConfigFile is used* ; Specifies Subscription(s) to be included in the analysis: "/subscriptions/YYYYYYYY-YYYY-YYYY-YYYY-YYYYYYYYYYYY","/subscriptions/AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA".
        - **RunbookFile**:  *Optional* ; specifies the file with the runbook (selectors & checks) to be used.
        - **ResourceGroups**:  *Optional if subscription(s) are provided or a ConfigFile is used* ; specifies Resource Group(s) to be included in the analysis: "/subscriptions/YYYYYYYY-YYYY-YYYY-YYYY-YYYYYYYYYYYY/resourceGroups/ResourceGroup1","/subscriptions/YYYYYYYY-YYYY-YYYY-YYYY-YYYYYYYYYYYY/resourceGroups/ResourceGroup2".
        - **Tags**:  *Optional* ; specifies tags to be used for filtering the resources: "TagName1==TagValue1","TagName2==TagValue2"
        - **ConfigFile**:  *Optional* ; specifies a file for advanced filtering, including: subscription, resourceGroup, resourceId, Tags.
          - See ConfigFile.Example [here](../../../../tools/configfile.example)
        - **AzureEnvironment**:  *Optional* ; specifies the Azure Environment to used for the analysis: AzureCloud, AzureUSGovernment.
        - **SAP**:  *Optional* ; used for specialized workload analysis.
        - **AVD**:  *Optional* ; used for specialized workload analysis.
        - **AVS**:  *Optional* ; used for specialized workload analysis.
        - **HPC**:  *Optional* ; used for specialized workload analysis.
        - **Debugging**: *Optional* ; Writes Debugging information of the script during the execution.
        {{< figure src="../../img/tools/collector-8.png" width="100%" >}}

2. Authenticate with the account that has Reader permissions to the target subscription(s)
  {{< figure src="../../img/tools/collector-9.png" width="40%" >}}

1. After script completes, the results will be saved to the same folder location.

## 2 - Data Analyzer Script

- [GitHub Link to Download](https://github.com/Azure/Azure-Proactive-Resiliency-Library-v2/blob/main/tools/2_wara_data_analyzer.ps1)
- Download the script using command-line
    ```shell
    iwr https://aka.ms/aprl/tools/2 -out 2_wara_data_analyzer.ps1
    ```
- [GitHub Link to Sample Output](https://github.com/Azure/Azure-Proactive-Resiliency-Library-v2/blob/main/tools/sample-output/WARA%20Action%20Plan%202024-05-07_12_07.xlsx)

The Data Analyzer PowerShell script is the second script in the Azure Proactive Resiliency Library (APRL) tooling suite. It compares the output collected by the Collector script with the Azure Proactive Resiliency Guidelines (APRL) and generates an ActionPlan Excel spreadsheet. The goal of this tool is to summarize the collected data and provide actionable insights into the health and resiliency of the Azure environment.

---

### Local Machine - Script Execution

**The Data Analyzer script must be run from a Windows Machine with Excel installed.**

1. Change your directory to the same location that you have downloaded the WARA Data Analyzer script to.

    - We recommend running this as close to your C:\ as path to avoid errors related to file path length.
    {{< figure src="../../img/tools/collector-7.png" width="40%" >}}

1. Execute script pointing the -JSONFile parameter to file created by the WARA Collector script.
  {{< figure src="../../img/tools/analyzer-1.png" width="100%" >}}

1. Select "R" to allow script to run
  {{< figure src="../../img/tools/analyzer-2.png" width="100%" >}}

1. After the script completes it will save a WARA Action Plan.xlsx file to the same file path.

### Local Machine - Action Plan Analysis

1. Once the script has completed, open the Excel Action Plan and familiarize yourself with the structure of the file, generated data, resources collected, pivot tables, and charts created.

    - These are the worksheets:
      - **Recommendations**: you will find all Recommendations, their category, impact, description, learn more links, and much more.
        - Note that Columns A and B are counting the number of Azure Resources associated with the RecommendationID.
      - **ImpactedResources**: you will find a list of Azure Resources associated with a RecommendationID. These are the Azure Resources NOT following Microsoft best practices for Reliability.
      - **Other-OutOfScope**: you will find a list of the Resources that are Out of Scope of the Wara engagement based on the ResourceTypes, after all filters have been applied.
      - **ResourceTypes**: you will find a list of all ResourceTypes the customer is using, number of Resources deployed for each one, and if there are Recommendations for the ResourceType in APRL.
      - **Outages**: you will find a list of all the outages that impacted the subscriptions (this worksheet might not exist if there are no Outages to be found).
      - **Retirements**: you will find a list of all the next retirements in the subscriptions (this worksheet might not exist if there are no Retirements to be found).
      - **Support Tickets**: you will find a list of all the Support Tickets for the subscriptions in the past 6 months (this worksheet might not exist if there are no Support Tickets to be found).
      - **PivotTable**: you will find a couple of pivot tables used to automatically create the charts
      - **Charts**: you will find 3 charts that will be used in the Executive Summary PPTx
    - At this point, all Azure Resources with recommendations and Azure Resource Graph queries available in APRL, were automatically validated. Follow the next steps to validate the remaining services without automation or that does not exist in APRL yet.

1. Go to the "ImpactedResources" worksheet, filter Column "B" by "IMPORTANT", and validate manually the remaining resource configurations for reliabilty patterns.

    - "IMPORTANT - Query under development"
    - "IMPORTANT - Recommendation cannot be validated with ARGs - Validate Resources manually"
    - "IMPORTANT - ServiceType Not Available in APRL - Validate Resources manually if Applicable, if not delete this line"

1. Remove/add any recommendations based on your analysis prior to generating reports

## 3 - Reports Generator Script

- [GitHub Link to Download](https://github.com/Azure/Azure-Proactive-Resiliency-Library-v2/blob/main/tools/3_wara_reports_generator.ps1)
- Download the script using command-line
    ```shell
    iwr https://aka.ms/aprl/tools/3 -out 3_wara_reports_generator.ps1
    ```
- Download the PowerPoint template using command-line
    ```shell
    iwr https://aka.ms/aprl/tools/pptx -out 'Mandatory - Executive Summary presentation - Template.pptx'
    ```
- Download the Word template using command-line
    ```shell
    iwr https://aka.ms/aprl/tools/docx -out 'Optional - Assessment Report - Template.docx'
    ```
- [GitHub Link to Sample Output - Executive Summary Presentation](https://github.com/Azure/Azure-Proactive-Resiliency-Library-v2/blob/main/tools/sample-output/Executive%20Summary%20Presentation%20-%20Contoso%20Hotels%20-%202024-05-07-12-12.pptx)
- [GitHub Link to Sample Output - Assessment Report](https://github.com/Azure/Azure-Proactive-Resiliency-Library-v2/blob/main/tools/sample-output/Assessment%20Report%20-%20Contoso%20Hotels%20-%202024-05-07-12-12.docx)

The Reports Generator PowerShell script serves as the final step in the Azure Proactive Resiliency Library (APRL) tooling suite. It takes the Excel spreadsheet generated by the Data Analyzer script and converts it into Microsoft Word and PowerPoint formats. The Reports Generator automates the process of creating comprehensive reports from the analyzed data, making it easier to share insights and recommendations.

---

### Local Machine - Report Generation

1. You will need to have both the Word and PowerPoint templates downloaded to the same file location.
  {{< figure src="../../img/tools/generator-1.png" width="80%" >}}

1. Change your directory to the same location that you have downloaded the WARA Reports Generator script to.

    - We recommend running this as close to your C:\ as path to avoid errors related to file path length.
    {{< figure src="../../img/tools/collector-7.png" width="40%" >}}

1. Execute script leveraging needed parameters

    - Parameters include:
      - **ExcelFile**:  *Mandatory*; WARA Excel file generated by '2_wara_data_analyzer.ps1' script and customized.
      - **CustomerName**:  *Optional*; specifies the Name of the Customer to be added to the PPTx and DOCx files.
      - **Heavy**:  *Optional*; runs the script at a lower pace to handle heavy environments.
      - **WorkloadName**:  *Optional*; specifies the Name of the Workload of the analyses to be added to the PPTx and DOCx files.
      - **PPTTemplateFile**:  *Optional*; specifies the PPTx template file to be used as source. If not specified the script will look for the file in the same path as the script.
      - **WordTemplateFile**:  *Optional*; specifies the DOCx template file to be used as source. If not specified the script will look for the file in the same path as the script.
      - **Debugging**: *Optional*; Writes a Debugging information to a log file.
    {{< figure src="../../img/tools/generator-2.png" width="100%" >}}

1. Select "R" to allow script to run
  {{< figure src="../../img/tools/generator-3.png" width="100%" >}}

1. After the script successfully runs, you will find two new files saved in your folder. Some of the information will be automatically populated based on the Action Plan.
{{< hint type=important >}}
Updates will need to be made prior to presenting to any audience.
{{< /hint >}}
