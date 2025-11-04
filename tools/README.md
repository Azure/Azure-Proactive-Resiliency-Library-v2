# Deploy the Azure Validation Workbook


You can deploy the workbook directly to your Azure environment using the button below.


[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2FAzure-Proactive-Resiliency-Library-v2%2Frefs%2Fheads%2Farclares-workbook%2Ftools%2FAzureValidationWorkbook.json)

Clicking this button will open the Azure Portal with your template pre-loaded for deployment.

1. Click the **Deploy to Azure** button above.
2. The Azure Portal will open a custom deployment blade with the workbook template pre-loaded.
3. Fill in the required fields (such as Subscription, Resource Group, Location, and Workbook Name).
4. Click **Review + create**, then **Create** to deploy the workbook.
5. After deployment, go to the selected Resource Group, find the deployed workbook under **Workbooks**, and open it.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Deployment Options](#deployment-options)
3. [Step-by-Step Deployment](#step-by-step-deployment)
4. [Permission Requirements](#permission-requirements)
5. [Workbook Structure](#workbook-structure)
6. [Cost Estimation Categories](#cost-estimation-categories)
7. [Operational Workflow](#operational-workflow)
8. [Customization Options](#customization-options)
9. [Export and Reporting](#export-and-reporting)

## Quick Reference

| Task | Action |
|------|--------|
| **Deploy Workbook** | Use `aka.ms/AzureValidationworkbook/deploy` |
| **Required Permissions** | Contributor (deployment) + Reader (monitoring) |
| **Enable Export** | Click "Yes" on Summary of Recommendations |
| **Export Results** | Click "Export to CSV" |
| **Update Pricing** | Click parameter → "Yes" → Enter new value |
| **Check for Updates** | Look for notification banner at top |


## Prerequisites

Before deploying the Azure Validation Workbook, ensure you have:

- **Azure subscription** with appropriate permissions
- **Contributor access** to the resource group where the workbook will be deployed
- **Reader permissions** across all subscriptions you want to monitor
- **Azure portal access** for deployment and operation

## Deployment Options

You have **two deployment methods**:

### Option 1: Deploy to Azure Button
- Click the **"Deploy to Azure"** button 


### Option 2: Direct Link
- Visit: `aka.ms/AzureValidationworkbook/deploy`


## Step-by-Step Deployment

### 1. Access Deployment Template
Choose one of the deployment options above to access the Azure Resource Manager template in the portal.

### 2. Configure Deployment Parameters

| Parameter | Description | Action Required |
|-----------|-------------|-----------------|
| **Subscription** | Target Azure subscription | Select appropriate subscription |
| **Resource Group** | Where the workbook will be created | Select existing or create new |
| **Region** | Azure region for workbook deployment | ⚠️ **Leave as default** |
| **Workbook Name** | Display name for the workbook | Use default or customize |
| **Workbook Type** | Template type | ⚠️ **Leave as default** |
| **Source ID** | Template source identifier | ⚠️ **Leave as default** |
| **Telemetry ID** | Telemetry tracking identifier | ⚠️ **Leave as default** |

### 3. Deploy the Workbook
1. Review all parameters
2. Click **"Review + create"**
3. Validate the configuration
4. Click **"Create"** to deploy

### 4. Access the Deployed Workbook
1. Navigate to the **resource group** where you deployed the workbook
2. Find the resource with type **"Workbook"**
3. Click on the workbook resource
4. Select **"Open Workbook"** to launch

## Permission Requirements

### Deployment Permissions
- **Contributor** role at the **resource group level** where the workbook will be deployed

### Operational Permissions
- **Reader** role across **all subscriptions** that will be monitored by the workbook

### Multi-Subscription Monitoring Example
If monitoring **2 subscriptions**:
- ✅ **Reader** access to Subscription A
- ✅ **Reader** access to Subscription B
- ✅ **Contributor** access to Resource Group (for deployment - can be revoked later.)

## Workbook Structure

The workbook is organized into **four main assessment tabs**:

### 1. 🔄 Backup Checks
- **VM Backup Status**: Identifies VMs without backup protection
- **Recovery Services Vault**: Security level and configuration assessment
- **Zone Redundancy**: Backup storage zone redundancy status
- **Cross-Region**: Cross-region backup configuration analysis

### 2. 🛡️ Security Checks
- **Defender for Cloud**: VM security agent status and recommendations
- **Security Configuration**: Security best practices assessment
- **Access Controls**: Identity and access management evaluation

### 3. 📊 Monitor Checks
- **Logging Configuration**: Azure Monitor and Log Analytics setup
- **Alerting**: Alert rule configuration and coverage
- **Observability**: Monitoring and diagnostic settings assessment

### 4. 🌐 Zone Adoption Checks
- **Availability Zones**: Multi-zone deployment recommendations
- **Zone-Redundant Services**: Service-specific zone redundancy analysis
- **Resiliency Assessment**: High availability configuration evaluation

## Cost Estimation Categories

The workbook provides three types of cost analysis:

### 🟢 Precise Cost Estimation
- **Description**: Exact monthly cost calculations available
- **Example**: Defender for Cloud agent = $14.60/month per VM
- **Customizable**: Users can modify pricing parameters
- **Default Pricing**: East US region, pay-as-you-go rates (September 2025)

### 🟡 Cost Impact
- **Description**: Percentage-based cost increase estimates
- **Example**: Cosmos DB zone redundancy = 25% increase
- **Use Case**: When precise costs depend on too many variables
- **Guidance**: Provides directional cost impact information

### 🔴 No Cost Estimation Available
- **Description**: Cost calculation not possible due to complexity
- **Display**: Shows "No cost estimation available"
- **Reason**: Too many variables or highly dependent on specific configurations
- **Action**: Refer to Azure Pricing Calculator for detailed estimates

## Operational Workflow

### For Factory Team Members

1. **Navigate to Overview Page**
   - Start with the main overview tab
   - Review summary of all findings

2. **Enable Summary of Recommendations**
   - Click **"Yes"** to show the summary table
   - This displays all recommendations across all tabs

3. **Review with Customer** (Optional)
   - Navigate through individual tabs (Backup, Security, Monitor, Zone Adoption)
   - Explain the specific checks being performed
   - Discuss findings and recommendations

4. **Export Recommendations**
   - Click **"Export to CSV"** from the summary table
   - Download contains all recommendations with cost impact categories

5. **Handover to CFTL**
   - Provide the CSV export to Customer Facing Technology Lead (CFTL) colleague
   - Include any relevant discussion notes from customer review

## Customization Options

### Pricing Parameter Modification
1. **Access Cost Parameters**
   - Navigate to any section with cost estimates
   - Look for pricing parameter controls

2. **Modify Costs**
   - Click on the parameter you want to change
   - Click **"Yes"** to enable editing
   - Enter new value (e.g., change $14.60 to $13.00)
   - Changes apply immediately to all calculations


## Export and Reporting

### CSV Export Contents
The exported CSV includes:

| Column | Description |
|--------|-------------|
| **ResourceName** | Name of the Azure resource |
| **ResourceType** | Type of Azure service |
| **ResourceGroup** | Resource group location |
| **Location** | Azure region |
| **Recommendation** | Specific improvement recommendation |
| **CostImpactCategory** | 🟢/🟡/🔴 cost classification |
| **EstimatedMonthlyCost** | Calculated monthly cost (when available) |
| **ImplementationImpact** | Business impact level (Low/Medium/High) |
| **ImplementationComplexity** | Technical complexity (Low/Medium/High) |
| **SubscriptionId** | Azure subscription identifier |




---

*Last Updated: September 26, 2025*  
