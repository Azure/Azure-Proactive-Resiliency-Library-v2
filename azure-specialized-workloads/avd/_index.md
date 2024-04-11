---
title: Azure Virtual Desktop
geekdocCollapseSection: true
geekdocHidden: false
---

## Dependent Azure Resource Recommendations

| Recommendation                                                                                                                                                                                                                                                                    |  Provider Namespace   |     Resource Type      |
| :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :-------------------: | :--------------------: |
| [(Pooled) Configure scheduled agent updates](../../../Azure-Proactive-Resiliency-Library-v2/azure-resources/DesktopVirtualization/hostPools/#pooled-configure-scheduled-agent-updates)                                                                                            | DesktopVirtualization |       hostPools        |
| [(Pooled) Create a validation pool for testing of planned updates](../../../Azure-Proactive-Resiliency-Library-v2/azure-resources/DesktopVirtualization/hostPools/#pooled-create-a-validation-pool-for-testing-of-planned-updates)                                                | DesktopVirtualization |       hostPools        |
| [(Personal) Create a validation pool for testing of planned updates](../../../Azure-Proactive-Resiliency-Library-v2/azure-resources/DesktopVirtualization/hostPools/#personal-create-a-validation-pool-for-testing-of-planned-updates)                                            | DesktopVirtualization |       hostPools        |
| [Replicate your Image Templates to a secondary region](../../../Azure-Proactive-Resiliency-Library-v2/azure-resources/VirtualMachineImages/imageTemplates/)                                                                                                                       | VirtualMachineImages  |     imageTemplates     |
| [Zone redundant storage should be used for image versions](../../../Azure-Proactive-Resiliency-Library-v2/azure-resources/VirtualMachineImages/imageTemplates/#replicate-your-image-templates-to-a-secondary-regions)                                                             |        Compute        |       galleries        |
| [Deploy VMs across Availability Zones](../../../Azure-Proactive-Resiliency-Library-v2/azure-resources/Compute/virtualMachines/#deploy-vms-across-availability-zones)                                                                                                              |        Compute        |    virtualMachines     |
| [Backup VMs with Azure Backup service](../../../Azure-Proactive-Resiliency-Library-v2/azure-resources/Compute/virtualMachines/#backup-vms-with-azure-backup-services)                                                                                                             |        Compute        |    virtualMachines     |
| [Production VMs should be using SSD disks](../../../Azure-Proactive-Resiliency-Library-v2/azure-resources/Compute/virtualMachines/#production-vms-should-be-using-ssd-disks)                                                                                                      |        Compute        |    virtualMachines     |
| [Configure diagnostic settings for all Azure Virtual Machines](../../../Azure-Proactive-Resiliency-Library-v2/azure-resources/Compute/virtualMachines/#configure-diagnostic-settings-for-all-azure-virtual-machines)                                                              |        Compute        |    virtualMachines     |
| [Connect on-prem networks to Azure critical workloads via multiple ExpressRoutes](../../../Azure-Proactive-Resiliency-Library-v2/azure-resources/Network/expressRouteCircuits/#connect-on-prem-networks-to-azure-critical-workloads-via-multiple-expressroutes)                   |        Network        |  expressRouteCircuits  |
| [Ensure ExpressRoute's physical links connect to distinct network edge devices](../../..https://azure.github.io/Azure-Proactive-Resiliency-Library-v2/azure-resources/Network/expressRouteCircuits/#ensure-expressroutes-physical-links-connect-to-distinct-network-edge-devices) |        Network        |  expressRouteCircuits  |
| [Choose a Zone-redundant gateway](../../../Azure-Proactive-Resiliency-Library-v2/azure-resources/Network/virtualNetworkGateways/#choose-a-zone-redundant-gateway)                                                                                                                 |        Network        | virtualNetworkGateways |
| [Configure NSG Flow Logs](../../../Azure-Proactive-Resiliency-Library-v2/azure-resources/Network/networkSecurityGroups/#configure-nsg-flow-logs)                                                                                                                                  |        Network        | networkSecurityGroups  |
| [Ensure that storage accounts are zone or region redundant](../../../Azure-Proactive-Resiliency-Library-v2/azure-resources/Storage/storageAccounts/#ensure-that-storage-accounts-are-zone-or-region-redundant)                                                                    |        Storage        |    storageAccounts     |

<br>

## Dependent Well-Architected Framework - Reliability Recommendations

| Recommendation                                                                                                                                                                                                                      | Reliability Stage |
| :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :---------------: |
| [Ensure that all fault-points and fault-modes are understood and operationalized](../../../Azure-Proactive-Resiliency-Library-v2/azure-waf/design/#ensure-that-all-fault-points-and-fault-modes-are-understood-and-operationalized) |      Design       |
| [Design a BCDR strategy that will help to meet the business requirements](../../../Azure-Proactive-Resiliency-Library-v2/azure-waf/design/#design-a-bcdr-strategy-that-will-help-to-meet-the-business-requirements)                 |      Design       |

<br>

## General Workload Guidance

{{< azure-specialized-workloads-recommendationlist name="azure-specialized-workloads-recommendationlist" >}}
