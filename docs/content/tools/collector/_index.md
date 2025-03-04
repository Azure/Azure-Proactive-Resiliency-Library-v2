---
title: Collector Cmdlet
weight: 10
geekdocCollapseSection: false
---

{{< toc >}}

## Overview

This PowerShell module is part of the Microsoft Well-Architected Reliability Assessment (WARA) engagement. It helps customers validate whether their Azure resources are architected and configured according to Microsoft best practices. The collector cmdlet (Start-WARACollector) achieves this by running Azure Resource Graph queries (Kusto/KQL) against Azure subscriptions and resources. Additionally, it collects information about closed support tickets, active Azure Advisor reliability recommendations, past Azure Service Health retirement and outage notifications, and the configuration of Azure Service Health alerts, all of which are relevant for the reliability recommendations provided at the end of the engagement. The collected data is then structured and exported into a JSON file, which is later used as input for the second step in the analysis process, the Data Analyzer cmdlet (start-WARAAnalyzer).

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
