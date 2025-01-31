---
title: Azure VMware Solution
geekdocCollapseSection: true
geekdocHidden: false
---

## Dependent Azure Resource Recommendations

| Recommendation                                                                                                                                                                                                                                                                      | Provider Namespace | Resource Type          |
| :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :----------------: | ---------------------- |
| [Monitor when Azure VMware Solution Private Cloud is reaching the capacity limit](../../../Azure-Proactive-Resiliency-Library-v2/azure-resources/AVS/privateClouds/#monitor-when-azure-vmware-solution-private-cloud-is-reaching-the-capacity-limit)                                |        AVS         | privateClouds          |
| [Monitor when Azure VMware Solution Cluster Size is approaching the host limit](../../../Azure-Proactive-Resiliency-Library-v2/azure-resources/AVS/privateClouds/#monitor-when-azure-vmware-solution-cluster-size-is-approaching-the-host-limit)                                    |        AVS         | privateClouds          |
| [Enable Stretched Clusters for Multi-AZ Availability of the vSAN Datastore](../../../Azure-Proactive-Resiliency-Library-v2/azure-resources/AVS/privateClouds/#enable-stretched-clusters-for-multi-az-availability-of-the-vsan-datastore)                                            |        AVS         | privateClouds          |
| [Configure Azure Monitor Alert warning thresholds for vSAN datastore utilization](../../../Azure-Proactive-Resiliency-Library-v2/azure-resources/AVS/privateClouds/#configure-azure-monitor-alert-warning-thresholds-for-vsan-datastore-utilization)                            |        AVS         | privateClouds          |
| [Configure Syslog in Diagnostic Settings for Azure VMware Solution](../../../Azure-Proactive-Resiliency-Library-v2/azure-resources/AVS/privateClouds/#configure-syslog-in-diagnostic-settings-for-azure-vmware-solution)                            |        AVS         | privateClouds          |
| [Monitor CPU Utilization to ensure sufficient resources for workloads](../../../Azure-Proactive-Resiliency-Library-v2/azure-resources/AVS/privateClouds/#monitor-cpu-utilization-to-ensure-sufficient-resources-for-workloads)                            |        AVS         | privateClouds          |
| [Monitor Memory Utilization to ensure sufficient resources for workloads](../../../Azure-Proactive-Resiliency-Library-v2/azure-resources/AVS/privateClouds/#monitor-memory-utilization-to-ensure-sufficient-resources-for-workloads)                            |        AVS         | privateClouds          |
| [Use key autorotation for vSAN datastore customer-managed keys](../../../Azure-Proactive-Resiliency-Library-v2/azure-resources/AVS/privateClouds/#use-key-autorotation-for-vsan-datastore-customer-managed-keys)                            |        AVS         | privateClouds          |
| [Use multiple DNS servers per private FQDN zone](../../../Azure-Proactive-Resiliency-Library-v2/azure-resources/AVS/privateClouds/#use-multiple-dns-servers-per-private-fqdn-zone)                            |        AVS         | privateClouds          |
| [For better data path performance enable FastPath on ExpressRoute Direct and Gateway](../../../Azure-Proactive-Resiliency-Library-v2/azure-resources/Network/connections/#for-better-data-path-performance-enable-fastpath-on-expressroute-direct-and-gateway)                      |      Network       | connections            |
| [Monitor gateway health](../../../Azure-Proactive-Resiliency-Library-v2/azure-resources/Network/virtualNetworkGateways/#monitor-gateway-health)                                                                                                                                     |      Network       | virtualNetworkGateways |
| [Configure customer-controlled gateway maintenance](../../../Azure-Proactive-Resiliency-Library-v2/azure-resources/Network/virtualNetworkGateways/#configure-customer-controlled-gateway-maintenance)                                                                               |      Network       | virtualNetworkGateways |

<br>

## General Workload Guidance

{{< azure-specialized-workloads-recommendationlist name="azure-specialized-workloads-recommendationlist" >}}
