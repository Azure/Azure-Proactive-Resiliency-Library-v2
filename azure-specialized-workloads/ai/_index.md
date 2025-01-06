---
title: Artificial Intelligence (GPT-RAG)
geekdocCollapseSection: true
geekdocHidden: false
---

## Dependent Azure Resource Recommendations

| Recommendation                                                                                                                                                                                                                                                                              | Provider Namespace | Resource Type |
| :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | :----------------: | :-----------: |
| [Monitor Batch account quota](../../../Azure-Proactive-Resiliency-Library-v2/azure-resources/Batch/batchAccounts/#monitor-batch-account-quota)                                                                                                                                              |       Batch        | batchAccounts |
| [Create an Azure Batch pool across Availability Zones](../../../Azure-Proactive-Resiliency-Library-v2/azure-resources/Batch/batchAccounts/#create-an-azure-batch-pool-across-availability-zones)                                                                                            |       Batch        | batchAccounts |
| [Deploy a PAYG instance of the model with provisioned throughput to manage overflow effectively](../../../Azure-Proactive-Resiliency-Library-v2/azure-resources/CognitiveServices/accounts/#deploy-a-PAYG-instance-of-the-model-with-provisioned-throughput-to-manage-overflow-effectively) | CognitiveServices  |   accounts    |
| [Ensure that models are deployed using Global batch for large scale processing](../../../Azure-Proactive-Resiliency-Library-v2/azure-resources/CognitiveServices/accounts/#ensure-that-models-are-deployed-using-global-batch-for-large-scale-processing)                                   | CognitiveServices  |   accounts    |
| [Ensure AOAI models are deployed using Data Zone Standard for data residency requirements](../../../Azure-Proactive-Resiliency-Library-v2/azure-resources/CognitiveServices/accounts/#ensure-aoai-models-are-deployed-using-data-zone-standard-for-data-residency-requirements)             | CognitiveServices  |   accounts    |
| [Create the Azure machine learning registry in multiple regions](../../../Azure-Proactive-Resiliency-Library-v2/azure-resources/MachineLearningServices/registries/#create-the-azure-machine-learning-registry-in-multiple-regions)             | MachineLearningServices  |   registries    |
| [Plan for a multi-regional deployment of Azure Machine Learning and associated resources](../../../Azure-Proactive-Resiliency-Library-v2/azure-resources/MachineLearningServices/workspaces/#plan-for-a-multi-regional-deployment-of-azure-machine-learning-and-associated-resources)             | MachineLearningServices  |   workspaces    |
| [Deploy Azure Machine learning workspace in secondary region](../../../Azure-Proactive-Resiliency-Library-v2/azure-resources/MachineLearningServices/workspaces/#deploy-azure-machine-learning-workspace-in-secondary-region)             | MachineLearningServices  |   workspaces    |
| [Ensure to create Machine Learning Compute resources in secondary region](../../../Azure-Proactive-Resiliency-Library-v2/azure-resources/MachineLearningServices/workspaces/#ensure-to-create-machine-learning-compute-resources-in-secondary-region)             | MachineLearningServices  |   workspaces    |
| [Configure API management service in multiple Azure regions](../../../Azure-Proactive-Resiliency-Library-v2/azure-resources/ApiManagement/service/#configure-api-management-service-in-multiple-azure-regions)             | ApiManagement  |   service    |
<br>

## General Workload Guidance

{{< azure-specialized-workloads-recommendationlist name="azure-specialized-workloads-recommendationlist" >}}
