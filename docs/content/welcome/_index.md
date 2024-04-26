---
title: Welcome
weight: 0
---

---

Welcome to the home of the Azure Proactive Resiliency Library v2 (APRL). The purpose of this site is to provide a curated catalog of resiliency recommendations for workloads running in Azure. Many of the recommendations contain supporting [Azure Resource Graph (ARG)](https://learn.microsoft.com/azure/governance/resource-graph/overview) queries to help identify non-compliant resources.

The site content is organized into four main sections:

1. [**Azure Resources:**]({{< ref "azure-resources/_index.md">}}) This section provides recommendations for individual Azure resources. Recommendations are organized by Azure resource provider and resource type.

1. [**Specialized Workloads:**]({{< ref "azure-specialized-workloads/_index.md">}}) This section provides recommendations for popular workload types. The recommendations cover multiple resource types and include workload specific guidance.

1. [**Well-Architected Framework:**]({{< ref "azure-waf/_index.md">}}) This section provides resiliency recommendations from the [Azure Well-Architected Framework](https://aka.ms/waf)

1. [**Tools:**]({{< ref "tools/_index.md">}}) This section provides automation scripts for workload evaluation. The scripts execute the ARG queries and create documents for analysis, reporting, and triage.

### Get Started

To get started head over to the [Azure Resources section]({{< ref "azure-resources/_index.md">}}) and then navigate to your chosen resource provider and resource type. Each of the listed resource types will provide recommendations, supporting documentation, and, when available, ARG queries.

{{< hint type=note >}}

You can also use the basic search functionality provided by this site to locate the Azure resource you are looking for.

{{< /hint >}}

### Contributing

Please see the [contribution guide here]({{< ref "contributing/_index.md">}}).
