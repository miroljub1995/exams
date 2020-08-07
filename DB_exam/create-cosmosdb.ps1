$ErrorActionPreference = "Stop"

Write-Host "Logging in..."
If ((Get-AzContext) -eq $null) {Connect-AzAccount | Out-Null}
Write-Host "Logged in"

$region = "West Europe"
$resourceGroupName = "database-rg"
$dbName = "Company"
$containerName = "Employees"

Write-Host "Creating CosmosDB..."
New-AzResourceGroupDeployment `
    -ResourceGroupName $resourceGroupName `
    -TemplateFile ".\cosmosdb-template.json" `
    -region $region `
    -databaseName $dbName `
    -containerName $containerName `
    | Out-Null
Write-Host "CosmosDB created"
