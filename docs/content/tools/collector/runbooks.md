# Overview

Runbooks are JSON files that allow extensive customization of KQL queries executed by WARA tooling and the resources these queries target. They also support the integration of custom KQL queries. Read on to learn more about using runbooks with WARA tooling.

## Selectors

Runbooks use selectors to identify groups of Azure resources for specific checks. [Selectors can be any valid KQL `where` condition.](https://learn.microsoft.com/azure/data-explorer/kusto/query/where-operator)

Here are a few examples of valid runbook selectors:

| Pattern | Example | Notes |
| --- | --- | --- |
| By tag | `tags['app'] =~ 'my_app'` | Matches all resources tagged `app`: `my_app` |
| By regex pattern | `name matches regex '^my_app\d{2}$'` | Matches `my_app01`, `my_app02`, `my_app03` ... |
| By name | `name in~ ('my_app01', 'my_app02', 'my_app03')` | Matches only `my_app01`, `my_app02`, `my_app03` |
| By resource group | `resourceGroup =~ 'my_group'` | Matches all resources in the `my_group` resource group |
| By subscription | `subscriptionId =~ '1235ec12-...'` | Matches all resources in subscription `1235ec12-...` |

Each selector has a name (which can be referenced later in specific checks) and is defined in a runbook like this:

```json
{
  "selectors": {
    "my_app_resources": "tags['app'] =~ 'my_app'",
    "my_group_resources": "resourceGroup =~ 'my_group'",
    "my_app_and_my_group": "tags['app'] =~ 'my_app' and resourceGroup =~ 'my_group'"
  }
}
```

Read on to learn how selectors and checks work together to run KQL queries against arbitrary groups of resources.

> When using selectors in this runbook, especially those that involve regex or string patterns, it is important to correctly escape backslashes due to the way Azure Resource Graph and JSON parsing handle these characters. Selectors are used to define groups of resources, and if you include patterns like regex within them, each backslash must be doubled for both JSON encoding and Azure Resource Graph interpretation. For instance, a single backslash (`\`) in your regex pattern needs to be written as four (`\\\\`) when defined in a JSON-based selector. This ensures compatibility at all levels of parsing. Failure to do so can lead to errors and improperly matched resources, so it’s critical to review and verify the formatting of your selectors when working with these escape sequences.

## Checks

Checks combine selectors with specific KQL queries to run precise checks on arbitrary sets of resources.

Here's an example using previously defined selectors:

```json
{
  "selectors": {
    "my_app_resources": "tags['app'] =~ 'my_app'",
    "my_group_resources": "resourceGroup =~ 'my_group'",
    "my_app_and_my_group_resources": "tags['app'] =~ 'my_app' and resourceGroup =~ 'my_group'"
  },
  "checks": {
    "122d11d7-b91f-8747-a562-f56b79bcfbdc": {
      "my_app_uses_managed_disks": "my_app_resources",
      "my_group_uses_managed_disks": "my_group_resources",
      "my_app_and_my_group_uses_managed_disks": "my_app_and_my_group_resources"
    }
  }
}
```

Let's break this down line by line:

- The `selectors` from the previous section are included to be used in the `checks` section of the runbook.
- A single check configuration is provided, using an existing [APRL KQL query to verify that VM resources are using managed disks (`122d11d7-b91f-8747-a562-f56b79bcfbdc`)](https://azure.github.io/Azure-Proactive-Resiliency-Library-v2/azure-resources/Compute/virtualMachines/#use-managed-disks-for-vm-disks).
- Three checks are defined, each applying to different selectors:
  - `my_app_uses_managed_disks`: Verifies that all resources with the tag `app` set to `my_app` use managed disks.
  - `my_group_uses_managed_disks`: Verifies that all resources in the `my_group` resource group use managed disks.
  - `my_app_and_my_group_uses_managed_disks`: Verifies that all resources in the `my_group` resource group with the tag `app` set to `my_app` use managed disks.

### How selectors are applied to KQL queries

There are two different ways in which selectors can be applied to KQL queries:

- **Explicitly**: Including a `// selector` comment in your KQL query will automatically inject the appropriate selector condition at runtime.
  - For example, given the example selectors provided above, configuring a check to use the `my_app_resources` selector would automatically replace `// selector` with `| where tags['app'] =~ 'my_app'` at runtime.
  - The best practice is to include `// selector` comments on their own line as, at runtime, they're automatically piped in as a `where` condition. This approach helps ensure that the merged KQL query is easily readable. Setting the `-Debugging` switch will output all merged queries at runtime for you review.
  - `// selector` is the "default selector". You can also reference specific selectors in your KQL queries using this syntax: `// selector:name` where `name` is the name of a selector defined in the runbook (e.g., `my_app_resource`). This makes it easy to reference different selector-defined groups of resources within the same KQL query.
- **Implicitly**: Most KQL queries including the default set included in APRL v2 don't include selector comments. Use the `-UseImplicitRunbookSelectors` script switch to automatically wrap every KQL query in an inner join that limits the scope of the query.

{{< hint type=important >}}
By default, implicit selectors will not be applied due to constraints on the total number of joins that can be included in a resource graph query. To use implicit selectors, you have to include the `-UseImplicitRunbookSelectors` switch when running the script.
{{< /hint >}}

By combining checks and selectors, you can easily define complex WARA review configurations using a simple JSON-based syntax.

### Parameters

Parameters offer a simple syntax for dynamically customizing selectors and KQL queries. Parameters are arbitrary key/value pairs that are included in the `parameters` section of a runbook like this:

```json
{
  "parameters": {
    "resource_group_name": "my_resource_group",
    "resource_tag_name": "my_tag",
    "resource_tag_value": "my_value"
  }
}
```

Parameters can easily be included in selectors like this:

```kusto
resourceGroup =~ '{{resource_group_name}}'
```

Parameters can also be included directly in queries like this:

```kusto
resources
| where tags['{{resource_tag_name}}'] =~ '{{resource_tag_value}}'
```

## Query overrides

While the set of KQL queries included with APRL v2 is very comprehensive, sometimes you need to run a check that's not included in APRL v2. For this reason, runbooks enable you to include additional catalogs of KQL queries in your review.

Query catalogs must follow this folder structure:

```plain
resources
|-- compute (resource provider name)
    |-- virtualmachines (resource name)
        |-- kql
            |-- 1fe03dbd-91e0-402c-a4f8-5611ae7b90b5.kql
            |-- 2bd0be95-a825-6f47-a8c6-3db1fb5eb387.kql
|-- network
    |-- virtualnetworks
        |-- kql
            |-- bd24415f-2532-4943-8fe0-283abf1e2339.kql
```

All queries must run the following properties:

| Name | Required | Description |
| --- | --- | --- |
| `recommendationId` | 🔴 | A GUID that uniquely identifies the query |
| `id` | 🔴 | If applicable, the ID of the resource under review; otherwise `n/a` |
| `name` | 🔴 | If applicable, the name of the resource under review; otherwise `n/a` |
| `tags` | 🔴 | If applicable, the tags on the resource under review; otherwise `n/a` |
| `param1` | | Additional information which will appear in the report |
| `param2` | | Additional information which will appear in the report |
| `param3` | | Additional information which will appear in the report |
| `param4` | | Additional information which will appear in the report |
| `param5` | | Additional information which will appear in the report |

You can define these query overrides in the runbook like this:

```json
{
  "query_overrides": [
    ".\\some_queries",
    "c:\\queries\\some_more_queries"
  ]
}
```

Given this configuration...

- The script will first load all the queries included in APRL v2.
- Next, the script will find all KQL files in `.\some_queries` and add them to the run.
  - If a new query has the same ID (`recommendationId`) as an existing query, the existing query will be overwritten.
  - If there is no existing query, the new query will be added to the run.
- Next, the script will look for all queries in the `c:\queries\some_more_queries` and apply the same logic as before: if a query has already been loaded with the same ID, it will replace the existing query; otherwise, it will simply load the new query.

{{< hint type=note >}}
Note that query paths can be absolute or relative to the location of the running script.
{{< /hint >}}
