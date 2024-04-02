---
title: Contributor Guide
weight: 20
geekdocCollapseSection: true
---

Looking to contribute to the Azure Proactive Resiliency Library v2 (APRL), well you have made it to the right place/page 👍

Follow the below instructions, especially the pre-requisites, to get started contributing to the library.

## Context/Background

Before jumping into the pre-requisites and specific section contribution guidance, please familiarize yourself with this context/background on how this library is built to help you contribute going forward.

This [site](https://aka.ms/aprl) is built using [Hugo](https://gohugo.io/), a static site generator, that's source code is stored in the [APRL GitHub repo](https://aka.ms/aprl/repo) (link in header of this site too) and is hosted on [GitHub Pages](https://pages.github.com), via the repo.

The reason for the combination of Hugo & GitHub pages is to allow us to present an easy to navigate and consume library, rather than using a native GitHub repo, which is not easy to consume when there are lots of pages and folders. Also Hugo generates the site in such a way that it is also friendly for mobile consumers.

### But I don't have any skills in Hugo?

That's okay and you really don't need them. Hugo just needs you to be able to author markdown (`.md`) files and it does the rest when it generates the site 👍

## Pre-Requisites

Read and follow the below sections to leave you in a "ready state" to contribute to APRL.

A "ready state" means you have a forked copy of the [`Azure/Azure-Proactive-Resiliency-Library` repo](https://aka.ms/aprl/repo) cloned to your local machine and open in VS Code.

## Run and Access a Local Copy of APRL During Development

When in VS Code you should be able to open a terminal and run the below commands to access a copy of the APRL website from a local web server, provided by Hugo, using the following address [`http://localhost:1313/Azure-Proactive-Resiliency-Library/`](http://localhost:1313/Azure-Proactive-Resiliency-Library/):

```text
hugo server --disableFastRender
```

### Software/Applications

To contribute to this project/repo/library, you will need the following installed:

{{< hint type=note >}}

You can use `winget` to install all the pre-requisites easily for you. See the [below section](#winget-install-commands)

{{< /hint >}}

- [Git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
- [Visual Studio Code (VS Code)](https://code.visualstudio.com/Download)
  - Extensions:
    - `editorconfig.editorconfig`, `streetsidesoftware.code-spell-checker`, `ms-vsliveshare.vsliveshare`, `medo64.render-crlf`, `vscode-icons-team.vscode-icons`
    - VS Code will recommend automatically to install these when you open this repo, or a fork of it, in VS Code.
- [Hugo Extended](https://gohugo.io/installation/)

### winget Install Commands

To install `winget` follow the [install instructions here.](https://learn.microsoft.com/windows/package-manager/winget/#install-winget)

```text
winget install --id 'Git.Git'
winget install --id 'Microsoft.VisualStudioCode'
winget install --id 'Hugo.Hugo.Extended'
```

### Other requirements

- [A GitHub profile/account](https://github.com/join)
- A fork of the [`Azure/Azure-Proactive-Resiliency-Library` repo](https://aka.ms/aprl/repo) into your GitHub org/account and cloned locally to your machine
  - Instructions on forking a repo and then cloning it can be found [here](https://docs.github.com/get-started/quickstart/fork-a-repo)

## Useful External Documentation

Below are links to a number of useful links to have when contributing to APRL:

- [GeekDocs Documentation Theme (that we use) - Docs](https://geekdocs.de/usage/getting-started/)
- [Hugo Quick Start](https://gohugo.io/getting-started/quick-start/)
- [Hugo Docs](https://gohugo.io/documentation/)
- [Markdown Cheat Sheet](https://www.markdownguide.org/cheat-sheet/)

## Steps to do before contributing anything (after pre-requisites)

Run the following commands in your terminal of choice from the directory where your fork of the repo is located:

```text
git checkout main
git pull
git fetch -p
git fetch -p upstream
git pull upstream main
git push
```

Doing this will ensure you have the latest changes from the upstream repo and you are ready to now create a new branch from `main` by running the below commands:

```text
git checkout main
git checkout -b <YOUR-DESIRED-BRANCH-NAME-HERE>
```

## Creating a pull request

Once you have committed changes to your fork of the APRL repo, you create a pull request to merge your changes into the APRL repo.

- [GitHub - Creating a pull request from a fork](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/proposing-changes-to-your-work-with-pull-requests/)

## Creating a Azure Resource's Recommendation Page

{{< hint type=important >}}

Make sure you have followed the the [Steps to do before contributing anything (after pre-requisites)](#steps-to-do-before-contributing-anything-after-pre-requisites) before following this section.

{{< /hint >}}

## Updating a Azure Resource's Recommendation Page

{{< hint type=important >}}

Make sure you have followed the the [Steps to do before contributing anything (after pre-requisites)](#steps-to-do-before-contributing-anything-after-pre-requisites) before following this section.

{{< /hint >}}

All you need to do is just make edits directly to the resource's `recommendation.yaml` file, save your changes, test your changes, commit, stage and push them to your branch and repo. Then [create a Pull Request](https://docs.github.com/pull-requests/collaborating-with-pull-requests/proposing-changes-to-your-work-with-pull-requests/creating-a-pull-request) into the `main` branch of the upstream repo and you are done. 👍

Here is a list of the required key-value pairs for each recommmendation within the `recommendation.yaml` file:

| Key                   | Example Value                                                                                                                                               | Data Type | Allowed Values                                                                                                                                                      | Description                                                                                                                                                                                  |
| :-------------------- | :---------------------------------------------------------------------------------------------------------------------------------------------------------- | :-------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------ | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| pageTitle             | Do not use classic Storage Account                                                                                                                          | String    | N/A                                                                                                                                                                 | Summarization of your recommendation                                                                                                                                                         |
| recommendationImpact  | High                                                                                                                                                        | String    | Low, Medium, High                                                                                                                                                   | Importance of adopting the recommendation and/or the risk of choosing not to adopt                                                                                                           |
| recommendationControl | Governance                                                                                                                                                  | String    | High Availability, Business Continuity, Disaster Recovery, Scalability, Monitoring and Alerting, Service Upgrade and Retirement, Other Best Practices, Personalized | Resiliency category associated with the recommendation                                                                                                                                       |
| tags                  | Not Workload Specific                                                                                                                                       | String    | N/A                                                                                                                                                                 | Generalized tags used for incorporating fields to automate                                                                                                                                   |
| publishedToLearn      | false                                                                                                                                                       | Boolean   | true, false                                                                                                                                                         | Indicates whether the recommendation is published to [Microsoft Learn](https://learn.microsoft.com/en-us/azure/well-architected/pillars)                                                     |
| publishToAdvisor      | false                                                                                                                                                       | Boolean   | true, false                                                                                                                                                         | Indicates whether the recommendation is published to Azure Advisor                                                                                                                           |
| pgVerified            | false                                                                                                                                                       | Boolean   | true, false                                                                                                                                                         | Indicates whether the recommendation is verified by the relevant product group                                                                                                               |
| automationAvailable   | true                                                                                                                                                        | Boolean   | true, false                                                                                                                                                         | Indicates whether automation is available for validating the recommendation                                                                                                                  |
| aprlRecommendationId  | 0a82ecb8-23ea-489a-823e-da73f0862de9                                                                                                                        | String    | 32-character hexadecimal string                                                                                                                                     | The unique identifier for the recommendation in the context of Azure Proactive Resiliency and CXObserve. Generate a [GUID](0a82ecb8-23ea-489a-823e-da73f0862de9) for each new recommendation |
| recommendationTypeId  | d0aeac4f-963d-4fdc-ad7a-d932d52db28e                                                                                                                        | String    | 32-character hexadecimal string                                                                                                                                     | The unique identifier for the recommendation in the context of Azure Advisor. Leave `null`.                                                                                                  |
| state                 | Active                                                                                                                                                      | String    | Active, Removed                                                                                                                                                     | Indicates whether the recommendation is visible                                                                                                                                              |
| longDescription       | Azure classic Storage Account will retire on August 31, 2024. So, migrate all workload from classic storage to v2.                                          | String    | N/A                                                                                                                                                                 | Detailed description of the recommendation and its implications                                                                                                                              |
| potentialBenefits     | Improved security and modern features                                                                                                                       | String    | The length should be less than 60 characters                                                                                                                        | The potential benefits of implementing the recommendation                                                                                                                                    |
| learnMoreLink         | - name: Storage Account Retirement Announcement url: "https://azure.microsoft.com/updates/classic-azure-storage-accounts-will-be-retired-on-31-august-2024" | Object    | Only 3 links per recommendation                                                                                                                                     | Links related to the recommendation, such as announcements or documentation                                                                                                                  |

{{< hint type=note >}}

Don't forget you can see your changes live by running a local copy of the APRL website by following the guidance [here.](#run-and-access-a-local-copy-of-aprl-during-development)

{{< /hint >}}

## Writing a recommendation

APRL recommendations are intended to enable and accelerate the delivery of Well Architected Reliability Assessments. The purpose of APRL is not to replace existing Azure public documentation and guidance on best practices.

Each recommendation should be actionable for the customer. The customer should be able to place the recommendation in their backlog and the engineer that picks it up should have complete clarity on the change that needs to be made and the specific resources that the change should be made to.

Each recommendation should include a descriptive title, a short guidance section that contains additional detail on the recommendation, links to public documentation that provide additional information related to the recommendation, and a query to identify resources that are not compliant with the recommendation. The title and guidance sections alone should provide sufficient information for a CSA to evaluate a resource.

Recommendations should not require the CSA to spend a lot of time on background reading, they should not be open to interpretation, and they should not be vague. Remember that the CSA delivering the WARA is reviewing a large number of Azure resources in a limited amount of time and is not an expert in every Azure resource.

### Examples

- Good recommendation: Use a /24 subnet for the resource
- Bad recommendation: Size your subnet appropriately

Not all best practices make good APRL recommendations. If the best practice relates to a particular resource configuration and can be checked with an ARG query, it probably makes for a good APRL recommendation. If the best practice is more aligned to general architectural concepts that are true for many Azure resources or workload types, we very likely already have a recommendation in the APRL WAF section that addresses the topic. If not, consider adding a WAF recommendation to APRL. If neither is the case, APRL may not be the best location for this content.

## Automation Standards for Recommendations

When creating recommendations for an Azure resource, please follow the below standards:

### Recommendation categories

Each recommendation should have _**one and only one**_ associated category from this list below.

| Recommendation Category |                                                                                                         Category Description                                                                                                         |
| :---------------------: | :----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------: |
| Application Resilience  |                Ensures software applications remain functional under failures or disruptions. Utilizes fault-tolerance, stateless architecture, and microservices to maintain application health and reduce downtime.                |
|       Automation        |                                Uses automated systems or scripts for routine tasks, backups, and recovery. Minimizes human intervention, thereby reducing errors and speeding up recovery processes.                                 |
|      Availability       |    Focuses on ensuring services are accessible and operational. Combines basic mechanisms like backups with advanced techniques like clustering and data replication to achieve near-zero downtime. (Includes High Availability)     |
|    Access & Security    |        Encompasses identity management, authentication, and security measures for safeguarding systems. Centralizes access control and employs robust security mechanisms like encryption and firewalls. (Includes Identity)         |
|       Governance        |  Involves policies, procedures, and oversight for IT resource utilization. Ensures adherence to legal, regulatory, and compatibility requirements, while guiding overall system management. (Includes Compliance and Compatibility)  |
|    Disaster Recovery    |                Involves strategies and technologies to restore systems and data after catastrophic failures. Utilizes off-site backups, recovery sites, and detailed procedures for quick recovery after a disaster.                 |
|    System Efficiency    | Maintains acceptable service levels under varying conditions. Employs techniques like resource allocation, auto-scaling, and caching to handle changes in load and maintain smooth operation. (Includes Performance and Scalability) |
|       Monitoring        |                     Involves constant surveillance of system health, performance, and security. Utilizes real-time alerts and analytics to identify and resolve issues quickly, aiding in faster response times.                     |
|       Networking        |                 Aims to ensure uninterrupted network service through techniques like failover routing, load balancing, and redundancy. Focuses on maintaining the integrity and availability of network connections.                 |
|         Storage         |                             Focuses on the integrity and availability of data storage systems. Employs techniques like RAID, data replication, and backups to safeguard against data loss or corruption.                             |

### Azure Resource Graph (ARG) Queries

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

|   Column Name    | Required |                                                            Information Returned (Example)                                                            |                                                      Description                                                       |
| :--------------: | :------: | :--------------------------------------------------------------------------------------------------------------------------------------------------: | :--------------------------------------------------------------------------------------------------------------------: |
| recommendationId |   Yes    |                                                                        aks-1                                                                         | The acronym of the Azure resource that the query is returning results for, followed by the APRL recommendation number. |
|       name       |   Yes    |                                                                       test-aks                                                                       |                The resource name of the Azure resource that does not adher to the APRL recommendation.                 |
|        id        |   Yes    | /subscriptions/00000000-0000-0000-0000-000000000000/resourcegroups/test-resource-group/providers/Microsoft.ContainerService/managedClusters/test-aks |                 The resource ID of the Azure resource that does not adhere to the APRL recommendation.                 |
|       tags       |    No    |                                                       {"Environment":"Test","Department":"IT"}                                                       |             Any relevant tags associated to the resource that does not adhere to the APRL recommendation.              |
|      param1      |    No    |                                                                networkProfile:kubenet                                                                |           Any additional information that is necessary to provide clarification for the APRL recommendation.           |
|      param2      |    No    |                                                                networkProfile:kubenet                                                                |           Any additional information that is necessary to provide clarification for the APRL recommendation.           |
|      param3      |    No    |                                                                networkProfile:kubenet                                                                |           Any additional information that is necessary to provide clarification for the APRL recommendation.           |
|      param4      |    No    |                                                                networkProfile:kubenet                                                                |           Any additional information that is necessary to provide clarification for the APRL recommendation.           |
|      param5      |    No    |                                                                networkProfile:kubenet                                                                |           Any additional information that is necessary to provide clarification for the APRL recommendation.           |

{{< hint type=note >}}

If you need support with validating a query, please reach out to the APRL team via the [APRL GitHub General Question/Feedback Form](https://github.com/Azure/Azure-Proactive-Resiliency-Library-v2/issues/new?assignees=&labels=feedback%2C+question&projects=&template=general-question-feedback----.md&title=%E2%9D%93%F0%9F%91%82+Question%2FFeedback+-+PLEASE+CHANGE+ME+TO+SOMETHING+DESCRIPTIVE)

{{< /hint >}}

## Top Tips

1. Sometimes the local version of the website may show some inconsistencies that don't reflect the content you have created.

{{< hint type=note >}}

If this happens, kill the Hugo local web server by pressing **CTRL** **+** **C** and then restart the Hugo web server by running `hugo server -D` from the root of the repo.

{{< /hint >}}
