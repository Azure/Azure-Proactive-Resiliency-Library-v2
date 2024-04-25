---
title: Azure Virtual Desktop
geekdocCollapseSection: true
geekdocHidden: false
---

## Dependent Azure Resource Recommendations

| Recommendation                                                                                                                                                                                                                                                                  |  Provider Namespace   |     Resource Type      |
|:--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|:---------------------:|:----------------------:|
| [Create a validation host pool for testing of planned updates](../../../Azure-Proactive-Resiliency-Library-v2/azure-resources/DesktopVirtualization/hostPools/#Create-a-validation-host-pool-for-testing-of-planned-updates)                                                   | DesktopVirtualization |       hostPools        |
| [Configure host pool scheduled agent updates](../../../Azure-Proactive-Resiliency-Library-v2/azure-resources/DesktopVirtualization/hostPools/#configure-host-pool-scheduled-agent-updates)                                                                                     | DesktopVirtualization |       hostPools        |
| [Ensure a unique OU is used when deploying host pools with domain joined session hosts](../../../Azure-Proactive-Resiliency-Library-v2/azure-resources/DesktopVirtualization/hostPools/#ensure-a-unique-ou-is-used-when-deploying-host-pools-with-domain-joined-session-hosts) | DesktopVirtualization |       hostPools        |
| [Use Azure Site Recovery or backups to protect VMs supporting personal desktops](../../../Azure-Proactive-Resiliency-Library-v2/azure-resources/DesktopVirtualization/hostPools/#use-azure-site-recovery-or-backups-to-protect-vms-supporting-personal-desktops)               | DesktopVirtualization |       hostPools        |
| [Scaling plans should be created per region and not scaled across regions](../../../Azure-Proactive-Resiliency-Library-v2/azure-resources/DesktopVirtualization/scalingPlans/#scaling-plans-should-be-created-per-region-and-not-scaled-across-regions)                        | DesktopVirtualization |      scalingPlans      |
| [Replicate your Image Templates to a secondary region](../../../Azure-Proactive-Resiliency-Library-v2/azure-resources/VirtualMachineImages/imageTemplates/#replicate-your-image-templates-to-a-secondary-region)                                                               |        Compute        |       galleries        |
| [A minimum of three replicas should be kept for production image versions](../../../Azure-Proactive-Resiliency-Library-v2/azure-resources/Compute/galleries/#a-minimum-of-three-replicas-should-be-kept-for-production-image-versions)                                         |        Compute        |       galleries        |
| [Zone redundant storage should be used for image versions](../../../Azure-Proactive-Resiliency-Library-v2/azure-resources/Compute/galleries/#zone-redundant-storage-should-be-used-for-image-versions)                                                                         |        Compute        |       galleries        |
| [Deploy VMs across Availability Zones](../../../Azure-Proactive-Resiliency-Library-v2/azure-resources/Compute/virtualMachines/#deploy-vms-across-availability-zones)                                                                                                           |        Compute        |    virtualMachines     |
| [Backup VMs with Azure Backup service](../../../Azure-Proactive-Resiliency-Library-v2/azure-resources/Compute/virtualMachines/#backup-vms-with-azure-backup-service)                                                                                                           |        Compute        |    virtualMachines     |
| [Production VMs should be using SSD disks](../../../Azure-Proactive-Resiliency-Library-v2/azure-resources/Compute/virtualMachines/#production-vms-should-be-using-ssd-disks)                                                                                                   |        Compute        |    virtualMachines     |
| [Configure diagnostic settings for all Azure Virtual Machines](../../../Azure-Proactive-Resiliency-Library-v2/azure-resources/Compute/virtualMachines/#configure-diagnostic-settings-for-all-azure-virtual-machines)                                                           |        Compute        |    virtualMachines     |
| [Connect on-prem networks to Azure critical workloads via multiple ExpressRoutes](../../../Azure-Proactive-Resiliency-Library-v2/azure-resources/Network/expressRouteCircuits/#connect-on-prem-networks-to-azure-critical-workloads-via-multiple-expressroutes)                |        Network        |  expressRouteCircuits  |
| [Ensure ExpressRoute's physical links connect to distinct network edge devices](../../../Azure-Proactive-Resiliency-Library-v2/azure-resources/Network/expressRouteCircuits/#ensure-expressroutes-physical-links-connect-to-distinct-network-edge-devices)                     |        Network        |  expressRouteCircuits  |
| [Use Zone-redundant ExpressRoute gateway SKUs](../../../Azure-Proactive-Resiliency-Library-v2/azure-resources/Network/virtualNetworkGateways/#use-zone-redundant-expressroute-gateway-skus)                                                                                    |        Network        | virtualNetworkGateways |
| [Configure NSG Flow Logs](../../../Azure-Proactive-Resiliency-Library-v2/azure-resources/Network/networkSecurityGroups/#configure-nsg-flow-logs)                                                                                                                               |        Network        | networkSecurityGroups  |
| [Ensure that storage accounts are zone or region redundant](../../../Azure-Proactive-Resiliency-Library-v2/azure-resources/Storage/storageAccounts/#ensure-that-storage-accounts-are-zone-or-region-redundant)                                                                 |        Storage        |    storageAccounts     |
| [Ensure that storage accounts are zone or region redundant](../../../Azure-Proactive-Resiliency-Library-v2/azure-resources/Storage/storageAccounts/#ensure-that-storage-accounts-are-zone-or-region-redundant)                                                                 |        Storage        |    storageAccounts     |
| [Enable Azure Private Link Service for Key vault](../../../Azure-Proactive-Resiliency-Library-v2/azure-resources/KeyVault/vaults/#enable-azure-private-link-service-for-key-vault)                                                                                             |       Keyvault        |         vaults         |
| [Configure Service Health Alerts](../../../Azure-Proactive-Resiliency-Library-v2/azure-resources/Insights/activityLogAlerts/#configure-service-health-alerts)                                                                                                                  |       Insights        |   activityLogAlerts    |

<br>

## Dependent Well-Architected Framework - Reliability Recommendations

| Recommendation                                                                                                                                                                                                                       | Reliability Stage |
| :----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :---------------: |
| [Ensure that all fault-points and fault-modes are understood and operationalized](../../../Azure-Proactive-Resiliency-Library-v2/azure-waf/design/#ensure-that-all-fault-points-and-fault-modes-are-understood-and-operationalized) |      Design       |
| [Design a BCDR strategy that will help to meet the business requirements](../../../Azure-Proactive-Resiliency-Library-v2/azure-waf/design/#design-a-bcdr-strategy-that-will-help-to-meet-the-business-requirements)                 |      Design       |

<br>

## General Workload Guidance

{{< azure-specialized-workloads-recommendationlist name="azure-specialized-workloads-recommendationlist" >}}
