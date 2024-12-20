---
title: Create Recommendations
weight: 10
geekdocCollapseSection: true
---

{{< toc >}}

This section provides guidance on how to create new recommendations. The following requirements should be followed:

## Adding New Recommendation

To contribute a new recommendation for an Azure resource, follow these steps:

1. Locate the `recommendations.yaml` file within the directory corresponding to the Azure resource, Azure WAF design principle, or specialized workload you want to add a recommendation for.

1. Open the `recommendations.yaml` file and copy the following YAML template:

    ```yaml
    - description: Your Recommendation Title Here (less than 100 characters)
      aprlGuid: Generate a Unique GUID using https://guidgenerator.com/online-guid-generator.aspx
      recommendationTypeId: null
      recommendationControl: HighAvailability/Business Continuity/Disaster Recovery/Scalability/Monitoring and Alerting/Service Upgrade and Retirement/Other Best Practices/Personalized/Governance
      recommendationImpact: Low/Medium/High
      recommendationResourceType: Friendly name to identity resource type
      recommendationMetadataState: Active
      longDescription: |
        Your Long Description Here
        (less than 300 characters)
      potentialBenefits: Potential Benefits of Implementing the Recommendation (less than 60 characters)
      pgVerified: false
      automationAvailable: false
      tags: null
      learnMoreLink:
        - name: Learn More
          url: "Link URL"
    ```

1. Customize the placeholders with your recommendation's specific details. See the [Recommendation Structure](#recommendation-structure) section for more information on each key-value pair.

1. Once you've added your recommendation, save the file.

1. To test your changes, spin up your local hugo server by running the following command within your terminal:

    ```bash
    hugo server --disableFastRender
    ```

1. Submit your changes by creating a pull request in the repository.

1. That's all! Your suggestion will be reviewed for potential inclusion in the Azure Proactive Resiliency Library.

1. Questions or need assistance? Don't hesitate to create a GitHub Issue for support.

{{< hint type=note >}}

If you encounter inconsistencies on the local version of the website that do not reflect your content updates, or errors unrelated to your changes, follow these steps:

1. Press **CTRL** **+** **C** to terminate the Hugo local web server.
2. Restart the Hugo web server by running `hugo server --disableFastRender` from the root of the repository.

{{< /hint >}}

### Recommendation Structure

The YAML structure for adding new recommendations consists of several key-value pairs, each providing specific information about the recommendation. Below is a table that describes each key-value pair:
| Key | Example Value | Data Type | Allowed Values | Description |
| :-------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :-------- | :----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| description | Monitor Batch Account quota | String | Less than 100 characters | Summarization of your recommendation |
| aprlGuid | 3464854d-6f75-4922-95e4-a2a308b53ce6 | String | 32-character hexadecimal string | The unique identifier for the recommendation in the context of APRL and CXObserve. Generate a [GUID](https://guidgenerator.com/online-guid-generator.aspx) for each new recommendation |
| recommendationTypeId | 3464854d-6f75-4922-95e4-a2a308b53ce6 | String | `null` until updated by the Azure Advisor team | The unique identifier for the recommendation in the context of Advisor. |
| recommendationControl | Monitoring and Alerting | String | [HighAvailability, BusinessContinuity, DisasterRecovery, Scalability, MonitoringAndAlerting, ServiceUpgradeAnd Retirement, OtherBestPractices, Personalized, Governance, Security](#recommendation-categories) | Resiliency category associated with the recommendation |
| recommendationImpact | Medium | String | Low, Medium, High | Importance of adopting the recommendation and/or the risk of choosing not to adopt |
| recommendationResourceType | Microsoft.Storage/storageAccounts | String | Align with the resource type | Friendly name to identity resource type |
| recommendationMetadataState | Active | String | Active, Disabled | Indicates whether the recommendation is visible |
| longDescription | To enable Cross-region disaster recovery and business continuity, ensure that the appropriate quotas are set for all user subscription Batch accounts. | String | The length should be less than 300 characters | Detailed description of the recommendation and its implications |
| potentialBenefits | Enhanced data redundancy and boosts availability | String | The length should be less than 60 characters | The potential benefits of implementing the recommendation |
| pgVerified | false | Boolean | true, false | Indicates whether the recommendation is verified by the relevant product group |
| automationAvailable | false| Boolean | true, false | Indicates whether automation is available for validating the recommendation |
| tags | null | String | null, AI, AVD, AVS, HPC, SAP | Indicates which type of specialized workload the recommendation is associated to. |
| learnMoreLink | - name: Learn More url: "<https://learn.microsoft.com/en-us/azure/reliability/reliability-batch#cross-region-disaster-recovery-and-business-continuity>" | Object | Only 1 link per recommendation | Links related to the recommendation, such as announcements or documentation |

### Recommendation Categories

Each recommendation should have _**one and only one**_ associated recommendationCategory from this list below.

|    Recommendation Category     | Summary                                                                                                                                                                                                                            |
| :----------------------------: | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|       HighAvailability        | Focuses on ensuring services remain accessible and operational with minimal downtime.                                                                                                                                              |
|      BusinessContinuity       | Involves strategies to maintain essential functions during and after a disaster, ensuring business operations continue.                                                                                                            |
|       DisasterRecovery        | Focuses on restoring systems and data after catastrophic failures, ensuring quick recovery post-disaster.                                                                                                                          |
|          Scalability           | Involves techniques to handle changes in load and maintain system performance under varying conditions.                                                                                                                            |
|    MonitoringAndAlerting     | Constant surveillance of system health, performance, and security, aiding in quick issue identification and resolution.                                                                                                            |
| ServiceUpgradAndRetirement | Addresses the planning and execution of system upgrades and the retirement of outdated services.                                                                                                                                   |
|      OtherBestPractices      | Encompasses miscellaneous best practices that improve system resilience, efficiency, and security.                                                                                                                                 |
|          Personalized          | Customized recommendations tailored to specific system requirements, configurations, or preferences.                                                                                                                               |
|           Governance           | Involves policies, procedures, and oversight for IT resource utilization. Ensures adherence to legal, regulatory, and compatibility requirements, while guiding overall system management. (Includes Compliance and Compatibility) |

## Writing a Meaningful Recommendation

When writing a recommendation, consider the following:

APRL recommendations are intended to enable and accelerate the delivery of Well Architected Reliability Assessments. The purpose of APRL is not to replace existing Azure public documentation and guidance on best practices.

Each recommendation should be actionable for the customer. The customer should be able to place the recommendation in their backlog and the engineer that picks it up should have complete clarity on the change that needs to be made and the specific resources that the change should be made to.

Each recommendation should include a descriptive title, a short guidance section that contains additional detail on the recommendation, links to public documentation that provide additional information related to the recommendation, and a query to identify resources that are not compliant with the recommendation. The title and guidance sections alone should provide sufficient information for a CSA to evaluate a resource.

Recommendations should not require the CSA to spend a lot of time on background reading, they should not be open to interpretation, and they should not be vague. Remember that the CSA delivering the WARA is reviewing a large number of Azure resources in a limited amount of time and is not an expert in every Azure resource.

### Examples

- Good recommendation: Use a /24 subnet for the resource
- Bad recommendation: Size your subnet appropriately

Not all best practices make good APRL recommendations. If the best practice relates to a particular resource configuration and can be checked with an ARG query, it probably makes for a good APRL recommendation. If the best practice is more aligned to general architectural concepts that are true for many Azure resources or workload types, we very likely already have a recommendation in the APRL WAF section that addresses the topic. If not, consider adding a WAF recommendation to APRL. If neither is the case, APRL may not be the best location for this content.
