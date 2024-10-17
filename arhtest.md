# a

## Resiliency recommendations summary

| Category | Priority |Recommendation |
|---------------|--------|---|
| [**Availability**](#availability) |:::image type="icon" source="../media/icon-recommendation-high.svg":::| [Configure at least two regions for high availability](#configure-at-least-two-regions-for-high-availability)|
| [**Disaster recovery**](#disaster-recovery) |:::image type="icon" source="../media/icon-recommendation-high.svg":::| [Enable service-managed failover for multi-region accounts with single write region](#enable-service-managed-failover-for-multi-region-accounts-with-single-write-region)|
||:::image type="icon" source="../media/icon-recommendation-high.svg":::| [Evaluate multi-region write capability](#evaluate-multi-region-write-capability)|
|| :::image type="icon" source="../media/icon-recommendation-high.svg"::: | [Choose appropriate consistency mode reflecting data durability requirements](#choose-appropriate-consistency-mode-reflecting-data-durability-requirements)|
||:::image type="icon" source="../media/icon-recommendation-high.svg":::| [Configure continuous backup mode](#configure-continuous-backup-mode)|

### Availability

#### **Configure at least two regions for high availability**

**Impact:** :::image type="icon" source="../media/icon-recommendation-high.svg":::

It is crucial to enable a secondary region on your Cosmos DB to achieve higher SLA. Doing so does not incur any downtime and it is as easy as selecting a pin on map. Cosmos DB instances utilizing Strong consistency need to configure at least three regions to retain write availability in case of one region failure. **[Learn More](https://learn.microsoft.com/)**

**Potential benefits:** Enhances SLA and resilience.

##### Azure Resource Graph

:::code language="kusto" source="~/azure-proactive-resiliency-library/docs/content/services/database/cosmosdb/code/cosmos-1/cosmos-1.kql":::

----

### Disaster recovery

#### **Enable service-managed failover for multi-region accounts with single write region**

**Impact:** :::image type="icon" source="../media/icon-recommendation-high.svg":::

Cosmos DB boasts high uptime and resiliency. Even so, issues may arise. With Service-Managed failover, if a region is down, Cosmos DB automatically switches to the next available region, requiring no user action. **[Learn More](https://learn.microsoft.com/)**

##### Azure Resource Graph

:::code language="kusto" source="~/azure-proactive-resiliency-library/docs/content/services/database/cosmosdb/code/cosmos-2/cosmos-2.kql":::

----

#### **Evaluate multi-region write capability**

**Impact:** :::image type="icon" source="../media/icon-recommendation-high.svg":::

Multi-region write capability allows for designing applications that are highly available across multiple regions, though it demands careful attention to consistency requirements and conflict resolution. Improper setup may decrease availability and cause data corruption due to unhandled conflicts. **[Learn More](https://learn.microsoft.com/)**

**Potential benefits:** Enhances high availability.

##### Azure Resource Graph

:::code language="kusto" source="~/azure-proactive-resiliency-library/docs/content/services/database/cosmosdb/code/cosmos-3/cosmos-3.kql":::

----

#### **Choose appropriate consistency mode reflecting data durability requirements**

**Impact:** :::image type="icon" source="../media/icon-recommendation-high.svg":::

In a globally distributed database, consistency level impacts data durability during regional outages. Understand data loss tolerance for recovery planning. Use Session consistency unless stronger is needed, accepting higher write latencies and potential write region impact from read-only outages.**[Learn More](https://learn.microsoft.com/)**

**Potential benefits:** Enhances data durability and recovery.

##### Azure Resource Graph

:::code language="kusto" source="~/azure-proactive-resiliency-library/docs/content/services/database/cosmosdb/code/cosmos-5/cosmos-5.kql":::

----

#### **Configure continuous backup mode**

**Impact:** :::image type="icon" source="../media/icon-recommendation-medium.svg":::

Cosmos DB's backup is always on, offering protection against data mishaps. Continuous mode allows for self-serve restoration to a pre-mishap point, unlike periodic mode which requires contacting Microsoft support, leading to longer restore times. **[Learn More](https://learn.microsoft.com/)**

**Potential Benefits:** Faster self-serve data restore.

##### Azure Resource Graph

:::code language="kusto" source="~/azure-proactive-resiliency-library/docs/content/services/database/cosmosdb/code/cosmos-5/cosmos-5.kql":::

----
