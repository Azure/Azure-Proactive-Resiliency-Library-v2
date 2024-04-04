---
title: Create Content from Templates
weight: 20
geekdocCollapseSection: true
---

This section provides information about creating new content from Hugo archetypes/templates. The following scenarios are covered:

{{< toc >}}

## Create a New Azure Resource Provider Namespace

1. Ensure you are in the root directory of the repository within your terminal.
1. Run the following hugo command within your terminal.

   ```bash
   hugo new --kind azure-provider-namespace  'azure-resources/Storage'
   ```

   {{< hint type=important >}}

   Replace `Storage` with the name of the Azure provider namespace you want to create. Ensure that the name aligns to the available resource providers found in the documentation [here](https://learn.microsoft.com/en-us/azure/templates/#find-resources).

   Also, ensure that it is formatted with no spaces and is using pascal case. For example, `MachineLearningServices` or `VirtualMachineImages`.

   {{< /hint >}}

1. You should see similar output within your terminal as shown below:

   ```text
   Content dir "C:\\Repos\\Reliability\\Azure-Proactive-Resiliency-Library-v2\\azure-resources\\Storage" created
   ```

## Create a New Azure Resource Type within an Existing Provider Namespace

1. Ensure you are in the root directory of the repository within your terminal
1. Run the following hugo command within your terminal

   ```bash
   hugo new --kind azure-resource-type 'azure-resources/Storage/locations'
   ```

   {{< hint type=important >}}

   Replace `storageAccounts` with the name of the Azure resource type you want to create. Ensure that the name aligns to the available resource types found in the documentation [here](https://learn.microsoft.com/en-us/azure/templates/#find-resources). At this time, we are only allowing the creation of resource types one level deep, so you cannot create a resource type that is nested within another resource type such as `Storage/storageAccounts/blobServices`.

   Also, ensure that it is formatted with no spaces and is using camel casing. For example, `automationAccounts` or `databaseAccounts`.

   {{< /hint >}}

1. You should see similar output within your terminal as shown below:

   ```text
   Content dir "C:\\Repos\\Reliability\\Azure-Proactive-Resiliency-Library-v2\\azure-resources\\Storage\\locations" created
   ```

1. You should now see a new directory created within the `azure-resources/Storage` directory, named after the Azure resource type you specified and containing the relevant folders and files to build out the resource type. You can also verify the creation by inspecting the resource type within your local Hugo site, which should have been rebuilt automatically with the change.

## Create a New Azure Specialized Workload

1. Ensure you are in the root directory of the repository within your terminal
1. Run the following hugo command within your terminal

   ```bash
   hugo new --kind azure-specialized-workload 'azure-specialized-workloads/oracle'
   ```

   {{< hint type=important >}}

   Replace `oracle` with the name of the you want to create.

   Also, ensure that it is formatted with no spaces and is using camel case. For example, `hpcOnAzure`.

   {{< /hint >}}

1. You should see similar output within your terminal as shown below:

   ```text
   Content dir "C:\\Repos\\Reliability\\Azure-Proactive-Resiliency-Library-v2\\azure-specialized-workloads\\oracle" created
   ```

1. You should now see a new directory created within the `azure-specialized` directory, named after the Azure specialized workload you specified. You can verify the creation by inspecting the directory in your local Hugo site, which should have been rebuilt automatically with the change.
