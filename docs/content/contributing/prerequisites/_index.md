---
title: Prerequisites
weight: 10
geekdocCollapseSection: true
---

### I'm not familiar with Hugo. Is that okay?

Absolutely! You don't need to be. Hugo simply requires you to know how to write markdown (`.md`) files, and it handles the rest when generating the site. 👍

## Prerequisites

To prepare for contributing to APRL, follow the steps below to ensure you're in a "ready state."

A "ready state" means you have forked the [`Azure/Azure-Proactive-Resiliency-Library` repository](https://aka.ms/aprl/repo), cloned it to your local machine, and opened it in VS Code.

## Running and Accessing a Local Copy of APRL During Development

While in VS Code, you can open a terminal and execute the commands below to access a local copy of the APRL website from a web server provided by Hugo. Access it using the following address: [`http://localhost:1313/Azure-Proactive-Resiliency-Library/`](http://localhost:1313/Azure-Proactive-Resiliency-Library/):

```text
hugo server --disableFastRender
```

### Required Software/Applications

To contribute to this project/repository/library, you will need the following installed:

{{< hint type=note >}}

You can use `winget` to easily install all the prerequisites. Refer to the [section below](#winget-install-commands) for installation commands.

{{< /hint >}}

- [Git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
- [Visual Studio Code (VS Code)](https://code.visualstudio.com/Download)
  - Extensions:
    - `editorconfig.editorconfig`, `streetsidesoftware.code-spell-checker`, `ms-vsliveshare.vsliveshare`, `medo64.render-crlf`, `vscode-icons-team.vscode-icons`
    - VS Code will automatically recommend installing these when you open this repository, or a fork of it, in VS Code.
- [Hugo Extended](https://gohugo.io/installation/)

### Installation with winget

To install the required software using `winget`, follow the [instructions here](https://learn.microsoft.com/windows/package-manager/winget/#install-winget).

```text
winget install --id 'Git.Git'
winget install --id 'Microsoft.VisualStudioCode'
winget install --id 'Hugo.Hugo.Extended'
```

### Additional Requirements

Ensure you meet the following prerequisites:

- [Create a GitHub profile/account](https://github.com/join)
- Fork the [`Azure/Azure-Proactive-Resiliency-Library` repository](https://aka.ms/aprl/repo) to your GitHub organization/account and clone it locally to your machine.
- Instructions for forking a repository and cloning it can be found [here](https://docs.github.com/get-started/quickstart/fork-a-repo).
