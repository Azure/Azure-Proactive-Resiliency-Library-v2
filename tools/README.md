# Deploy the Azure Validation Workbook


You can deploy the workbook directly to your Azure environment using the button below.


[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2FAzure-Proactive-Resiliency-Library-v2%2Frefs%2Fheads%2Farclares-workbook%2Ftools%2FAzureValidationWorkbookTPID.json)

Clicking this button will open the Azure Portal with your template pre-loaded for deployment.

1. Click the **Deploy to Azure** button above.
2. The Azure Portal will open a custom deployment blade with the workbook template pre-loaded.
3. Fill in the required fields (such as Subscription, Resource Group, Location, and Workbook Name).
4. Click **Review + create**, then **Create** to deploy the workbook.
5. After deployment, go to the selected Resource Group, find the deployed workbook under **Workbooks**, and open it.

## How to Use the Workbook


1. **Set Filters:**
	- At the top of the workbook, use the Subscription, Resource Group, and Tag filters to scope your analysis.
	- You can select multiple subscriptions or resource groups as needed.

2. **Review Insights:**
	- Navigate through the tabs (Overview, Resiliency, BCDR, Security, Monitor) to see best-practice checks and recommendations.
	- Click on tiles or tables to drill into specific findings.

3. **Export Results:**
	- Most tables and visuals have an “Export to Excel” or “Export to CSV” option (look for the export/download icon above the table).
	- Use this to download findings for offline analysis or reporting.

4. **Take Action:**
	- Use the recommendations and impacted resource lists to prioritize remediation.
	- Track progress by exporting and updating the CSV as you address findings.

5. **Discuss Results with the Customer:**
	- Review the findings and recommendations with the customer to ensure understanding and alignment on next steps.

6. **Send to CFTL for Follow-up:**
	- Share the results with the CFTL person so they can follow up with the account team about implementing recommendations for the customer.

### Tips
- If you cannot save, verify you have Contributor or Workbook Contributor permissions on the chosen save scope.

