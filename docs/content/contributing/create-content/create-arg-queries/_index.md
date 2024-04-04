---
title: Create ARG Queries
weight: 30
geekdocCollapseSection: true
---

This section provides guidance on how to create new Azure Resource Graph (ARG) queries. The following requirements should be followed:

{{< toc >}}

## Requirements for ARG Queries

1. All ARG queries should have two comments at the top of the query, one comment stating `Azure Resource Graph Query` and another comment providing a description of the query results returned. For example:

   ```kql
   // Azure Resource Graph Query
   // Provides a list of Azure Container Registry resources that do not have soft delete enabled
   ```

1. If the ARG query is under development, the query should have a single line stating: `// under-development`

1. If a recommendation query cannot be returned due to limitations with the data provided within ARG, the query should have a single line stating: `// cannot-be-validated-with-arg`

1. Queries should only return resources that do not adhere to the APRL recommendation. For example, if the recommendation is to enable soft delete for Azure Container Registries, the associated query should only return Azure Container Registry resources that do not have soft delete enabled.

1. If a ARG query folder has a file with a file type suffixed with `.fix`, this means that the current query does not work as anticipated and to consider using this as a starting point for fixing the query. Once you have validated that the query is working as anticipated, please remove the file with the `.fix` suffix.

1. ARG query columns name returned should only include the following:

{{< hint type=note >}}

The column names should be in the order they are listed and match exactly.

{{< /hint >}}

|   Column Name    | Required |                                                            Information Returned (Example)                                                            |                                            Description                                             |
| :--------------: | :------: | :--------------------------------------------------------------------------------------------------------------------------------------------------: | :------------------------------------------------------------------------------------------------: |
| recommendationId |   Yes    |                                                         4f63619f-5001-439c-bacb-8de891287727                                                         |                        The aprlGuid associated to the APRL recommendation.                         |
|       name       |   Yes    |                                                                       test-aks                                                                       |      The resource name of the Azure resource that does not adhere to the APRL recommendation.      |
|        id        |   Yes    | /subscriptions/00000000-0000-0000-0000-000000000000/resourcegroups/test-resource-group/providers/Microsoft.ContainerService/managedClusters/test-aks |       The resource ID of the Azure resource that does not adhere to the APRL recommendation.       |
|       tags       |    No    |                                                       {"Environment":"Test","Department":"IT"}                                                       |   Any relevant tags associated to the resource that does not adhere to the APRL recommendation.    |
|      param1      |    No    |                                                                networkProfile:kubenet                                                                | Any additional information that is necessary to provide clarification for the APRL recommendation. |
|      param2      |    No    |                                                                networkProfile:kubenet                                                                | Any additional information that is necessary to provide clarification for the APRL recommendation. |
|      param3      |    No    |                                                                networkProfile:kubenet                                                                | Any additional information that is necessary to provide clarification for the APRL recommendation. |
|      param4      |    No    |                                                                networkProfile:kubenet                                                                | Any additional information that is necessary to provide clarification for the APRL recommendation. |
|      param5      |    No    |                                                                networkProfile:kubenet                                                                | Any additional information that is necessary to provide clarification for the APRL recommendation. |

{{< hint type=note >}}

If you need support with validating a query, please reach out to the APRL team via the [APRL GitHub General Question/Feedback Form](https://github.com/Azure/Azure-Proactive-Resiliency-Library-v2/issues/new?assignees=&labels=feedback%2C+question&projects=&template=general-question-feedback----.md&title=%E2%9D%93%F0%9F%91%82+Question%2FFeedback+-+PLEASE+CHANGE+ME+TO+SOMETHING+DESCRIPTIVE)

{{< /hint >}}

## Requirements for ARG Query Files

1. All query files should be named to match the aprlGuid for the respective APRL recommendation. For instance, if the aprlGuid for a recommendation is `4f63619f-5001-439c-bacb-8de891287727`, then the associated query file should be named `4f63619f-5001-439c-bacb-8de891287727.kql`.

1. All query files should be placed in the relevant kql folder within the relevant directory. For example, if the recommendation is for Azure Container Registries, the query file should be placed in the `azure-resources\ContainerRegistry\registries\kql` directory.

## Requirements for Pull Requests Containing ARG Queries

All pull requests that modify and/or create ARG queries should contain a screenshot of the query results returned from the Azure Resource Graph Explorer. The screenshot should be taken from the Azure Resource Graph Explorer and should include a resource that is not adhering to the APRL recommendation. This is to ensure that the query is returning the expected results and to validate that the columns are populated correctly.
