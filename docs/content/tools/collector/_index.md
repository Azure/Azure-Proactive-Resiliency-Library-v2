---
title: Collector Cmdlet
weight: 10
geekdocCollapseSection: false
---

{{< toc >}}

## Overview

This PowerShell module is part of the Microsoft Well-Architected Reliability Assessment (WARA) engagement. It helps customers validate whether their Azure resources are architected and configured according to Microsoft best practices. The collector cmdlet (Start-WARACollector) achieves this by running Azure Resource Graph queries (Kusto/KQL) against Azure subscriptions and resources. Additionally, it collects information about closed support tickets, active Azure Advisor reliability recommendations, past Azure Service Health retirement and outage notifications, and the configuration of Azure Service Health alerts, all of which are relevant for the reliability recommendations provided at the end of the engagement. The collected data is then structured and exported into a JSON file, which is later used as input for the second step in the analysis process, the Data Analyzer cmdlet (start-WARAAnalyzer).

{{< hint type=warning >}}
We are aware of an issue with Az.ResourceGraph PowerShell module 1.0.2 that causes the WARA Collector to fail when running against non-commercial environments. This is due to an issue with the Az.ResourceGraph PowerShell module 1.0.2, which is a dependency of the WARA Collector. If you are working on your own computer, you can downgrade to Az.ResourceGraph 1.0.0 or 1.0.1 to work around this issue. The Az.ResourceGraph module is available in the PowerShell Gallery.

When installing a new instance of the WARA module, it will automatically install the latest version of Az.ResourceGraph and Az.Accounts. If you are using the WARA module in an environment where you need a fresh install of the module and will be working in a non-commercial environment, please use `Install-PSResource WARA`. This will install the latest version of the WARA module with Az.Accounts 3.0.0 and Az.ResourceGraph 1.0.0. Please ensure that Az.ResourceGraph is not already installed in your environment. If it is, please uninstall it first using `Uninstall-Module Az.ResourceGraph`. You can then install the WARA module using `Install-PSResource WARA` and it will install the correct version of Az.ResourceGraph.
{{< /hint >}}

{{< hint type=important >}}
These Azure Resource Graph queries only read ARM (Azure Resource Manager) data. They do not access or collect any keys, secrets, passwords, or other confidential information. The queries only gather information about how resources are deployed and configured. If you would like to learn more, you can explore the Azure Resource Graph Explorer and run some of the query examples provided in the Azure portal.
{{< /hint >}}

## Requirements

[Requirements for the WARA PowerShell module collector](https://github.com/Azure/Well-Architected-Reliability-Assessment?tab=readme-ov-file#requirements)

- [PowerShell 7.4](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell?view=powershell-7.4)
- [Azure PowerShell modules](https://learn.microsoft.com/en-us/powershell/azure/install-azps-windows?view=azps-12.1.0&tabs=powershell&pivots=windows-psgallery)
  - Az.ResourceGraph PowerShell Module 1.0 or later
  - Az.Accounts PowerShell Module 3.0 or later
- Role Based Access Control: Reader role to access to resources to be evaluated

## Quick Start (Cloud Shell or Local Machine)

### Quick Workflow Example

```PowerShell
# Assume we running from a C:\WARA directory

# Installs the WARA module from the PowerShell Gallery.
Install-Module WARA

# Imports the WARA module to the PowerShell session.
Import-Module WARA

# Start the WARA collector.
Start-WARACollector -TenantID "00000000-0000-0000-0000-000000000000" -SubscriptionIds "/subscriptions/00000000-0000-0000-0000-000000000000"

# Assume output from collector is 'C:\WARA\WARA_File_2024-04-01_10_01.json'
Start-WARAAnalyzer -JSONFile 'C:\WARA\WARA_File_2024-04-01_10_01.json'

# Assume output from analyzer is 'C:\WARA\Expert-Analysis-v1-2025-02-04-11-14.xlsx'
Start-WARAReport -ExpertAnalysisFile 'C:\WARA\Expert-Analysis-v1-2025-02-04-11-14.xlsx'

#You will now have your PowerPoint and Excel reports generated under the C:\WARA directory.
```

### Start-WARACollector

These instructions are the same for any platform that supports PowerShell. The following instructions have been tested on Azure Cloud Shell, Windows, and Linux.

You can review all of the parameters on the Start-WARACollector [here](https://github.com/Azure/Well-Architected-Reliability-Assessment/blob/main/docs/wara/Start-WARACollector.md).

{{< hint type=note >}}
Whatever directory you run the `Start-WARACollector` cmdlet in, the Excel file will be created in that directory. For example: if you run the `Start-WARACollector` cmdlet in the `C:\Temp` directory, the Excel file will be created in the `C:\Temp` directory.
{{< /hint >}}

1. Install the WARA module from the PowerShell Gallery.

```powershell
# Installs the WARA module from the PowerShell Gallery.
Install-Module WARA
```

1. Import the WARA module.

```powershell
# Import the WARA module.
Import-Module WARA
```

1. Start the WARA collector. (Replace these values with your own)

```powershell
# Start the WARA collector.
Start-WARACollector -TenantID "00000000-0000-0000-0000-000000000000" -SubscriptionIds "/subscriptions/00000000-0000-0000-0000-000000000000"
```

## Resource Filtering

The filtering capabilities are designed for targeting specific Azure resources, enabling precise and flexible reliability assessments. The scope of the feature includes functionalities that allow users to define the scope and tags and criteria of their reliability checks using parameters or text files.

### Order of operations

1. Subscriptions
    - Subscription scopes like `-SubscriptionIds "/subscriptions/00000000-0000-0000-0000-000000000000"` or `[subscriptionIds]`

    `/subscriptions/11111111-1111-1111-1111-111111111111` in a configuration file always take explicit precedence over any smaller, more specific scope.

1. Resource Groups
    - These scopes can be used explicitly where you need to grab a resource group from a subscription but not evaluate the whole subscription.

1. Tags
    - When your resources have been explicitly scoped as above - the script will then further refine your results based on the tags provided to the script via parameters or configuration file.

### Filtering Considerations

- If you set a subscription filter for `subscription1` and you also set a resource group filter for `subscription1/resourcegroups/rg-demo1` your results will contain **all** of the resources in `subscription1`
  - This is because we specified `subscription1` and so all of `subscription1` will be evaluated. If we only wanted to evaluate `subscription1/resourcegroups/rg-demo1` then we would include that resource group as a filter and not the full subscription.
- If you set a subscription filter for `subscription2` and a resourcegroup filter for `subscription1/resourcegroups/rg-demo1` you will evaluate all of `subscription2` and only the resource group `rg-demo-1`.
- Setting a subscription filter for `subscription3`, a resource group filter for `subscription1/resourcegroups/rg-demo1`, and a tag filter for `environment=~prod` will return only resources or those in resource groups tagged with `environment=~prod` within subscription3 and `subscription1/resourcegroups/rg-demo1`.

### Tags Filtering

The tag filtering feature can be broken into two distinct types:

- `=~` Equals (non-case sensitive) to define your name/value pair values.
- `!~` Not Equals (non-case sensitive) to define your name/value pair values.

These tags can be further broken down into their `Key:Value` pairs and allow for the following logical operands:

- `||` Or operations, when one or more TagName(s) could be equal to one or more TagValue(s).

This separator to separate name/value pairs.

- `,` to separate name/value pairs.

This allows you to build logical tag filtering:

- The following example shows where the tag name can be `App` or `Application` and the value attributed to these tag names must be `App1` or `App2`. In addition, a new entry acts as an `AND` operator. So the first line must be true, so must the second line where we state that the tag name can be `env` or `environment` and the value can be `prod` or `production`. Only when all of these criteria are met would a resource become included in the output file.

In the configFile.txt the configuration looks like:

```text
[tags]
App||Application=~App1||App2
env||environment=~prod||production
```

In PowerShell command line the configuration looks like:

```powershell
-tags "App||Application=~App1||App2","env||environment=~prod||production""
```

- Our next example will demonstrate how we can filter using a `NOT` operator. This will return all resources in scope, except those that meet the requirements of `app` or `application` not equalling `App3`, `env` or `environment` not equalling `dev` or `qa`.

In the configFile.txt the configuration looks like:

```text
[tags]
App||Application!~App3
env||environment!~dev||qa
```

In PowerShell command line the configuration looks like:

```powershell
-tags "App||Application!~App3","env||environment!~dev||qa""
```

### Examples

#### Run the collector against a specific subscription

```PowerShell
Start-WARACollector -TenantID "00000000-0000-0000-0000-000000000000" -SubscriptionIds "/subscriptions/00000000-0000-0000-0000-000000000000"
```

#### Run the collector against a multiple specific subscriptions

```PowerShell
Start-WARACollector -TenantID "00000000-0000-0000-0000-000000000000" -SubscriptionIds @("/subscriptions/00000000-0000-0000-0000-000000000000","/subscriptions/00000000-0000-0000-0000-000000000001")
```

#### Run the collector against a specific subscription and resource group

```PowerShell
Start-WARACollector -TenantID "00000000-0000-0000-0000-000000000000" -SubscriptionIds "/subscriptions/00000000-0000-0000-0000-000000000000" -ResourceGroups "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/RG-001"
```

#### Run the collector against a specific resource group

```PowerShell
Start-WARACollector -TenantID "00000000-0000-0000-0000-000000000000" -ResourceGroups "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/RG-001"
```

#### Run the collector against a specific resource group and filtering by tag key/values

```PowerShell
Start-WARACollector -TenantID "00000000-0000-0000-0000-000000000000" -ResourceGroups "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/RG-001" -Tags "Env||Environment"
```

#### Run the collector against a specific subscription and resource group and filtering by tag key/values

```PowerShell
Start-WARACollector -TenantID "00000000-0000-0000-0000-000000000000" -SubscriptionIds "/subscriptions/00000000-0000-0000-0000-000000000000" -ResourceGroups "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/RG-001" -Tags "Env||Environment!~Dev||QA" -AVD -SAP -HPC -AVS -AI_GPT_RAG
```

#### Run the collector against a specific subscription and resource group, filtering by tag key/values and using the specialized resource types (AVD, SAP, HPC, AVS, AI_GPT_RAG)

```PowerShell
Start-WARACollector -TenantID "00000000-0000-0000-0000-000000000000" -SubscriptionIds "/subscriptions/00000000-0000-0000-0000-000000000000" -ResourceGroups "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/RG-001" -Tags "Env||Environment!~Dev||QA" -AVD -SAP -HPC -AI_GPT_RAG -AVS
```

#### Run the collector using a configuration file

```PowerShell
Start-WARACollector -ConfigFile "C:\path\to\config.txt"
```

#### Run the collector using a configuration file and using the specialized resource types (AVD, SAP, HPC, AVS, AI_GPT_RAG)

```PowerShell
Start-WARACollector -ConfigFile "C:\path\to\config.txt" -SAP -AVD -HPC -AVS -AI_GPT_RAG
```
