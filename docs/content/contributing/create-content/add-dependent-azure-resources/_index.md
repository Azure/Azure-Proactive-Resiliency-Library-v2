---
title: Add Dependent Azure Resources for Specialized Workloads
weight: 20
geekdocCollapseSection: true
---

{{< toc >}}

This section provides information about referecing dependent Azure resources for specialized workloads. The following scenarios are covered:

## Add Dependent Azure Resources for Specialized Workloads

1. Go to the relevant specialized workload directory within the `azure-specialized-workloads` directory.
1. Open the `_index.md` file within the specialized workload directory.
1. Add the dependent Azure resources to the **Dependent Azure Resource Recommendations** table where the following columns are required:

    - **Recommendation**: This will be a markdown URL built using recommendation key that links to the `description` key within the dependent Azure Resource YAML file and the path to the directory

    - **Provider Namespace**: The provider namespace of the Azure resource. Utilize the `recommendationResourceType` key within the dependent Azure Resource YAML file. So if the `recommendationResourceType` key is `Microsoft.Compute/virtualMachines`, the provider namespace would be `Compute`.

    - **Resource Type**: The resource type of the Azure resource. Utilize the `recommendationResourceType` key within the dependent Azure Resource YAML file. So if the `recommendationResourceType` key is `Microsoft.Compute/virtualMachines`, the resource type would be `virtualMachines`.

## Example of a Dependent Azure Resource Recommendation Table

See the markdown example below for a dependent Azure resource recommendation table:

  ```markdown
    | Recommendation                                                                                                                                                                                                                         |  Provider Namespace   | Resource Type |
    |:---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|:---------------------:|:-------------:|
    | [(Personal) Create a validation pool for testing of planned updates](../../../Azure-Proactive-Resiliency-Library-v2/azure-resources/DesktopVirtualization/hostPools/#personal-create-a-validation-pool-for-testing-of-planned-updates) | DesktopVirtualization |   hostPools   |
    | [(Pooled) Configure scheduled agent updates](../../../Azure-Proactive-Resiliency-Library-v2/azure-resources/DesktopVirtualization/hostPools/#pooled-configure-scheduled-agent-updates)                                                 | DesktopVirtualization |   hostPools   |
  ```
