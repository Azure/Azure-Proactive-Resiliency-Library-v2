---
title: Azure VMware Solution
geekdocCollapseSection: true
geekdocHidden: false
---

## Dependent Azure Resource Recommendations

| Recommendation                                                                                                                                                                                                                                                                      | Provider Namespace | Resource Type          |
| :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :----------------: | ---------------------- |
| [Configure Azure Service Health notifications and alerts for Azure VMware Solution](../../../Azure-Proactive-Resiliency-Library-v2/azure-resources/AVS/privateClouds/#configure-azure-service-health-notifications-and-alerts-for-azure-vmware-solution)                            |        AVS         | privateClouds          |
| [Monitor when Azure VMware Solution Private Cloud is reaching the capacity limit](../../../Azure-Proactive-Resiliency-Library-v2/azure-resources/AVS/privateClouds/#monitor-when-azure-vmware-solution-private-cloud-is-reaching-the-capacity-limit)                                |        AVS         | privateClouds          |
| [Monitor when Azure VMware Solution Cluster Size is approaching the host limit](../../../Azure-Proactive-Resiliency-Library-v2/azure-resources/AVS/privateClouds/#monitor-when-azure-vmware-solution-cluster-size-is-approaching-the-host-limit)                                    |        AVS         | privateClouds          |
| [Enable Stretched Clusters for Multi-AZ Availability of the vSAN Datastore](../../../Azure-Proactive-Resiliency-Library-v2/azure-resources/AVS/privateClouds/#enable-stretched-clusters-for-multi-az-availability-of-the-vsan-datastore)                                            |        AVS         | privateClouds          |
| [Verify vSAN FTT configuration aligns with the cluster size](../../../Azure-Proactive-Resiliency-Library-v2/azure-resources/AVS/privateClouds/#verify-vsan-ftt-configuration-aligns-with-the-cluster-size)                                                                          |        AVS         | privateClouds          |
| [For better data path performance enable FastPath on ExpressRoute Direct and Gateway](../../../Azure-Proactive-Resiliency-Library-v2/azure-resources/Network/connections/#for-better-data-path-performance-enable-fastpath-on-expressroute-direct-and-gateway)                      |      Network       | connections            |
| [Configure an Azure Resource Lock on connections to prevent accidental deletion](../../../Azure-Proactive-Resiliency-Library-v2/azure-resources/Network/connections/#configure-an-azure-resource-lock-on-connections-to-prevent-accidental-deletion)                                |      Network       | connections            |
| [Configure an Azure Resource lock for ExpressRoute Gateway to prevent accidental deletion](../../../Azure-Proactive-Resiliency-Library-v2/azure-resources/Network/virtualNetworkGateways/#configure-an-azure-resource-lock-for-expressroute-gateway-to-prevent-accidental-deletion) |      Network       | virtualNetworkGateways |
| [Monitor gateway health](../../../Azure-Proactive-Resiliency-Library-v2/azure-resources/Network/virtualNetworkGateways/#monitor-gateway-health)                                                                                                                                     |      Network       | virtualNetworkGateways |
| [Configure customer-controlled gateway maintenance](../../../Azure-Proactive-Resiliency-Library-v2/azure-resources/Network/virtualNetworkGateways/#configure-customer-controlled-gateway-maintenance)                                                                               |      Network       | virtualNetworkGateways |

<br>

## General Workload Guidance

{{< azure-specialized-workloads-recommendationlist name="azure-specialized-workloads-recommendationlist" >}}
