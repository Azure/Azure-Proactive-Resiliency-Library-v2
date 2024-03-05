---
title: Contributor Guide
weight: 15
geekdocCollapseSection: true
---
{{< hint type=warning >}}

Currently we can only accept contributions from Microsoft FTEs. In the future we will look to change this

{{< /hint >}}

Looking to contribute to the Azure Proactive Resiliency Library (APRL), well you have made it to the right place/page 👍

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
cd docs
hugo server -D
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

## Useful Resources

Below are links to a number of useful resources to have when contributing to AMBA:

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

Once you have committed changes to your fork of the AMBA repo, you create a pull request to merge your changes into the AMBA repo.

- [GitHub - Creating a pull request from a fork](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/proposing-changes-to-your-work-with-pull-requests/)

## Creating a Service's Recommendation Page

{{< hint type=important >}}

Make sure you have followed the the [Steps to do before contributing anything (after pre-requisites)](#steps-to-do-before-contributing-anything-after-pre-requisites) before following this section.

{{< /hint >}}

The is a common task that is likely to be done is adding a new service to which you want to provide recommendations and supporting queries etc. for example Virtual Machines.

For this task we use [Hugo's archetype](https://gohugo.io/content-management/archetypes/) features which enables you to create a whole directory for a new service with a lot of templated content ready for you to change and use. This can be called by using the following command `hugo new --kind service-bundle services/<category>/<service-name`

You can see source code of the directory archetype called `service-bundle` [here in the repo.](https://github.com/Azure/Azure-Proactive-Resiliency-Library/tree/main/docs/archetypes/service-bundle)

{{< hint type=note >}}

For the steps below we will use the Virtual Machine service as an example. Please change this to the service you are wanting to create.

{{< /hint >}}

Steps to follow:

1. In your terminal of choice run the following:

    ```text
    cd docs/
    hugo new --kind service-bundle services/compute/virtual-machines
    ```

1. You will now see a new folder in `content/services/compute` called `virtual-machines`

    ```text
    ├───content
    │   ├───contributing
    │   └───services
    │       ├───ai-ml
    │       ├───compute
    │       │   └───virtual-machines
    │       │       └───code
    │       │           ├───cm-1
    │       │           └───cm-2
    ```

1. Inside the `virtual-machines` folder you will see the following files pre-staged

    ```text
    │       │   └───virtual-machines
    │       │       │   _index.md
    │       │       │
    │       │       └───code
    │       │           ├───cm-1
    │       │           │       cm-1.azcli
    │       │           │       cm-1.kql
    │       │           │       cm-1.ps1
    │       │           │
    │       │           └───cm-2
    │       │                   cm-2.azcli
    │       │                   cm-2.kql
    │       │                   cm-2.ps1
    ```

1. Open `_index.md` in VS Code and make relevant changes
    - You can copy the recommendations labelled `CM-1` or `CM-2` multiple times to create more recommendations
1. Update Azure Resource Graph queries, PowerShell, AZCLI scripts in the `code` folder within `virtual-machines`
    - You will see there is a folder, e.g. `cm-1`, `cm-2`, per recommendation to help with file structure organization
1. Ensure you use the correct Azure resource abbreviations provided within our Cloud Adoption Framework (CAF) documentation [here](https://docs.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/resource-abbreviations). For example, use `vm` for Virtual Machines.
1. Save, commit and push your changes to your branch and repo
1. Create a [create a Pull Request](https://docs.github.com/pull-requests/collaborating-with-pull-requests/proposing-changes-to-your-work-with-pull-requests/creating-a-pull-request) into the `main` branch of the upstream repo
1. Get it merged

{{< hint type=note >}}

Don't forget you can see your changes live by running a local copy of the APRL website by following the guidance [here.](#run-and-access-a-local-copy-of-aprl-during-development)

{{< /hint >}}

## Automation Standards for Recommendations

When creating recommendations for a service, please follow the below standards:

### Recommendation categories

Each recommendation should have _**one and only one**_ associated category from this list below.

  | Recommendation Category | Category Description |
  |:---:|:---:|
  | Application Resilience | Ensures software applications remain functional under failures or disruptions. Utilizes fault-tolerance, stateless architecture, and microservices to maintain application health and reduce downtime. |
  | Automation | Uses automated systems or scripts for routine tasks, backups, and recovery. Minimizes human intervention, thereby reducing errors and speeding up recovery processes. |
  | Availability | Focuses on ensuring services are accessible and operational. Combines basic mechanisms like backups with advanced techniques like clustering and data replication to achieve near-zero downtime. (Includes High Availability) |
  | Access & Security | Encompasses identity management, authentication, and security measures for safeguarding systems. Centralizes access control and employs robust security mechanisms like encryption and firewalls. (Includes Identity) |
  | Governance | Involves policies, procedures, and oversight for IT resource utilization. Ensures adherence to legal, regulatory, and compatibility requirements, while guiding overall system management. (Includes Compliance and Compatibility) |
  | Disaster Recovery | Involves strategies and technologies to restore systems and data after catastrophic failures. Utilizes off-site backups, recovery sites, and detailed procedures for quick recovery after a disaster. |
  | System Efficiency | Maintains acceptable service levels under varying conditions. Employs techniques like resource allocation, auto-scaling, and caching to handle changes in load and maintain smooth operation. (Includes Performance and Scalability) |
  | Monitoring | Involves constant surveillance of system health, performance, and security. Utilizes real-time alerts and analytics to identify and resolve issues quickly, aiding in faster response times. |
  | Networking | Aims to ensure uninterrupted network service through techniques like failover routing, load balancing, and redundancy. Focuses on maintaining the integrity and availability of network connections. |
  | Storage | Focuses on the integrity and availability of data storage systems. Employs techniques like RAID, data replication, and backups to safeguard against data loss or corruption. |

### Azure Resource Graph (ARG) Queries

1. All ARG queries should have two comments at the top of the query, one comment stating  `Azure Resource Graph Query` and another comment providing a description of the query results returned. For example:

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

  | Column Name | Required | Information Returned (Example) | Description |
  |:---:|:---:|:---:|:---:|
  | recommendationId | Yes | aks-1 | The acronym of the Azure service that the query is returning results for, followed by the APRL recommendation number. |
  | name | Yes | test-aks | The resource name of the Azure resource that does not adher to the APRL recommendation. |
  | id | Yes | /subscriptions/00000000-0000-0000-0000-000000000000/resourcegroups/test-resource-group/providers/Microsoft.ContainerService/managedClusters/test-aks | The resource ID of the Azure resource that does not adhere to the APRL recommendation. |
  | tags | No | {"Environment":"Test","Department":"IT"} | Any relevant tags associated to the resource that does not adhere to the APRL recommendation. |
  | param1 | No | networkProfile:kubenet | Any additional information that is necessary to provide clarification for the APRL recommendation. |
  | param2 | No | networkProfile:kubenet | Any additional information that is necessary to provide clarification for the APRL recommendation. |
  | param3 | No | networkProfile:kubenet | Any additional information that is necessary to provide clarification for the APRL recommendation. |
  | param4 | No | networkProfile:kubenet | Any additional information that is necessary to provide clarification for the APRL recommendation. |
  | param5 | No | networkProfile:kubenet | Any additional information that is necessary to provide clarification for the APRL recommendation. |

{{< hint type=note >}}

If you need support with validating a query, please reach out to the APRL team via the [APRL GitHub General Question/Feedback Form](https://github.com/Azure/Azure-Proactive-Resiliency-Library/issues/new?assignees=&labels=feedback%2C+question&projects=&template=general-question-feedback----.md&title=%E2%9D%93%F0%9F%91%82+Question%2FFeedback+-+PLEASE+CHANGE+ME+TO+SOMETHING+DESCRIPTIVE)

{{< /hint >}}

### Azure PowerShell Scripts

1. All PowerShell scripts should have two comments at the top of the script, one comment stating `Azure PowerShell script` and another comment providing a description of the script results returned. For example:

    ```powershell
    # Azure PowerShell script
    # Provides a list of Azure Container Registry resources that do not have soft delete enabled
    ```

1. Scripts should only return resources that do not adhere to the APRL recommendation. For example, if the recommendation is to enable soft delete for Azure Container Registries, the associated scripts should only return Azure Container Registry resources that do not have soft delete enabled.

1. Scripts should exclusively contain code to retrieve resources that do not comply with the APRL recommendation. They should not include supporting code, such as Azure sign-in ([Connect-AzAccount](https://learn.microsoft.com/en-us/powershell/module/az.accounts/connect-azaccount), Login-AzAccount) or subscription selection ([Set-AzContext](https://learn.microsoft.com/en-us/powershell/module/az.accounts/set-azcontext), Select-AzSubscription). Execute these cmdlets separately from the APRL recommendation PowerShell script.

1. The script should return the result as an array of the `PSCustomObject` data type, with each result object containing only the following properties:

    {{< hint type=note >}}

    The property names should be in the order they are listed and match exactly.

    {{< /hint >}}

    | Property Name | Data Type | Required | Information Returned (Example) | Description |
    |:---:|:---:|:---:|:---:|---|
    | recommendationId | string | Yes | aks-1 | The acronym of the Azure service that the query is returning results for, followed by the APRL recommendation number. |
    | name | string | Yes | test-aks | The resource name of the Azure resource that does not adher to the APRL recommendation. |
    | id | string | Yes | /subscriptions/00000000-0000-0000-0000-000000000000/resourcegroups/test-resource-group/providers/Microsoft.ContainerService/managedClusters/test-aks | The resource ID of the Azure resource that does not adhere to the APRL recommendation. |
    | tags | PSCustomObject | No | {"Environment":"Test","Department":"IT"} | Any relevant tags associated to the resource that does not adhere to the APRL recommendation. The data type should match the data type of `tags` in the result of ARG queries by [Search-AzGraph](https://learn.microsoft.com/en-us/powershell/module/az.resourcegraph/search-azgraph). If not set tags, set `$null`. |
    | param1 | string | No | networkProfile:kubenet | Any additional information that is necessary to provide clarification for the APRL recommendation. |
    | param2 | string | No | networkProfile:kubenet | Any additional information that is necessary to provide clarification for the APRL recommendation. |
    | param3 | string | No | networkProfile:kubenet | Any additional information that is necessary to provide clarification for the APRL recommendation. |
    | param4 | string | No | networkProfile:kubenet | Any additional information that is necessary to provide clarification for the APRL recommendation. |
    | param5 | string | No | networkProfile:kubenet | Any additional information that is necessary to provide clarification for the APRL recommendation. |

    Below is a sample code to return a result that aligned to the above standards.

    ```powershell
    [PSCustomObject] @{
        recommendationId = 'aks-1'
        name             = $resource.Name
        id               = $resource.Id
        tags             = if ($resource.Tags) { [PSCustomObject] ([Hashtable] $resource.Tags) } else { $null }
        param1           = 'networkProfile:kubenet'
        param2           = 'networkProfile:kubenet'
        param3           = 'networkProfile:kubenet'
        param4           = 'networkProfile:kubenet'
        param5           = 'networkProfile:kubenet'
    }
    ```

    {{< hint type=note >}}

    If you need support with validating a script, please reach out to the APRL team via the [APRL GitHub General Question/Feedback Form](https://github.com/Azure/Azure-Proactive-Resiliency-Library/issues/new?assignees=&labels=feedback%2C+question&projects=&template=general-question-feedback----.md&title=%E2%9D%93%F0%9F%91%82+Question%2FFeedback+-+PLEASE+CHANGE+ME+TO+SOMETHING+DESCRIPTIVE)

    {{< /hint >}}

## Updating a Service's Recommendation Page

{{< hint type=important >}}

Make sure you have followed the the [Steps to do before contributing anything (after pre-requisites)](#steps-to-do-before-contributing-anything-after-pre-requisites) before following this section.

{{< /hint >}}

This is likely the most common task that will be performed.

All you need to do is just make edits directly to the existing markdown (`.md`) files, save your changes, commit, stage and push them to your branch and repo. Then [create a Pull Request](https://docs.github.com/pull-requests/collaborating-with-pull-requests/proposing-changes-to-your-work-with-pull-requests/creating-a-pull-request) into the `main` branch of the upstream repo and you are done 👍

{{< hint type=note >}}

Don't forget you can see your changes live by running a local copy of the APRL website by following the guidance [here.](#run-and-access-a-local-copy-of-aprl-during-development)

{{< /hint >}}

## Creating a Service Category

{{< hint type=important >}}

Make sure you have followed the the [Steps to do before contributing anything (after pre-requisites)](#steps-to-do-before-contributing-anything-after-pre-requisites) before following this section.

{{< /hint >}}

For this task we use [Hugo's archetype](https://gohugo.io/content-management/archetypes/) features which enables you to create a whole directory for a new service with a lot of templated content ready for you to change and use. This can be called by using the following command `hugo new --kind category-bundle services/<category>`

You can see source code of the directory archetype called `category-bundle` [here in the repo.](https://github.com/Azure/Azure-Proactive-Resiliency-Library/tree/main/docs/archetypes/category-bundle)

{{< hint type=note >}}

For the steps below we will use the AAA category as an example. Please change this to the category you are wanting to create.

{{< /hint >}}

Steps to follow:

1. In your terminal of choice run the following:

    ```text
    cd docs/
    hugo new --kind category-bundle services/aaa
    ```

1. You will now see a new folder in `content/services` called `aaa`

    ```text
    ├───content
    │   │   _index.md
    │   │
    │   ├───contributing
    │   │       _index.md
    │   │
    │   └───services
    │       │   _index.md
    │       │
    │       ├───aaa
    │       │       _index.md
    ```

1. Inside the `aaa` folder you will see the following file `_index.md` pre-staged

    ```text
    ├───aaa
    │       │       _index.md
    ```

1. Open `_index.md` in VS Code and make relevant changes
1. Save, commit and push your changes to your branch and repo
1. Create a [create a Pull Request](https://docs.github.com/pull-requests/collaborating-with-pull-requests/proposing-changes-to-your-work-with-pull-requests/creating-a-pull-request) into the `main` branch of the upstream repo
1. Get it merged

{{< hint type=note >}}

Don't forget you can see your changes live by running a local copy of the APRL website by following the guidance [here.](#run-and-access-a-local-copy-of-aprl-during-development)

{{< /hint >}}

## Top Tips

1. Sometimes the local version of the website may show some inconsistencies that don't reflect the content you have created.

   - If this happens, kill the Hugo local web server by pressing **CTRL** **+** **C** and then restart the Hugo web server by running `hugo server -D` from the root of the repo.
