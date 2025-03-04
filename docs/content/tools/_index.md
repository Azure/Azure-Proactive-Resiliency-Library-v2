---
title: Tools
weight: 47
geekdocCollapseSection: true
---

This section lists all of the guidance for the new APRL tooling and automation released 3-4-2025. With this release the APRL automation scripts are now included in a PowerShell module available in the PowerShell Gallery. The spreadsheet produced by the analyzer script has also been updated to improve the workload analysis process and customer deliverable.

The modules are expected to be run sequentially, starting with the collector, then analyzer, and finally reports. The collector module evaluates the Azure resources, executes Azure Resource Graph queries, and outputs a json file. The analyzer module takes the json file as an input and produces an Excel file. After the contents of the Excel file produced by the analyzer module have been reviewed, the reports module takes the Excel file as an input and produces a PowerPoint and an Excel file.

The guidance for the modules can be found in the following sections:

- [WARA Collector Documentation](/Azure-Proactive-Resiliency-Library-v2/tools/collector)
- [WARA Analyzer Documentation](/Azure-Proactive-Resiliency-Library-v2/tools/analyzer)
- [WARA Reports Documentation](/Azure-Proactive-Resiliency-Library-v2/tools/reports)

{{< toc >}}
