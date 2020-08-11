Import-Module -Name ..\Utils
Initialize-Shell
Check-Login

Write-Host "Creating resource group..."
$resourceGroupName = "exam6"
$location = "switzerlandnorth"
New-AzResourceGroup -Name $resourceGroupName -Location $location | Out-Null
Write-Host "Resource group created."

Write-Host "Creating 2 web apps..."
$appName1 = "simple-web-app-1"
$appName2 = "simple-web-app-2"
$region1 = "Central US"
$region2 = "West Europe"
$hostingPlanName1 = "ASP-exam6-1"
$hostingPlanName2 = "ASP-exam6-2"
New-AzResourceGroupDeployment `
    -ResourceGroupName $resourceGroupName `
    -TemplateFile .\web-app-template.json `
    -TemplateParameterFile .\web-app-parameters.json `
    -location $region1 `
    -appName $appName1 `
    -hostingPlanName $hostingPlanName1 `
    | Out-Null
New-AzResourceGroupDeployment `
    -ResourceGroupName $resourceGroupName `
    -TemplateFile .\web-app-template.json `
    -TemplateParameterFile .\web-app-parameters.json `
    -location $region2 `
    -appName $appName2 `
    -hostingPlanName $hostingPlanName2 `
    | Out-Null
Write-Host "Web apps created."

Write-Host "Creating front door..."
$fdName = "simple-app-frontend"
$fdLocation = "global"
New-AzResourceGroupDeployment `
    -ResourceGroupName $resourceGroupName `
    -TemplateFile .\front-door-template.json `
    -resourceName $fdName `
    -location $fdLocation `
    | Out-Null
Write-Host "Front door created"