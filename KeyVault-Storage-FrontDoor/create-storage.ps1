Import-Module -Name ..\Utils
Initialize-Shell
Check-Login

Write-Host "Creating resource group..."
$resourceGroupName = "exam6"
$location = "switzerlandnorth"
New-AzResourceGroup -Name $resourceGroupName -Location $location | Out-Null
Write-Host "Resource group created."

Write-Host "Creating storage account..."
$storageAccountName = "simplestorage1"
New-AzResourceGroupDeployment -ResourceGroupName $resourceGroupName -TemplateFile .\storage-template.json -TemplateParameterFile .\storage-parameters.json -storageAccountName $storageAccountName | Out-Null
$ctx = (Get-AzStorageAccount -Name $storageAccountName -ResourceGroupName $resourceGroupName).Context
Write-Host "Storage account created."

Write-Host "Creating Blob container..."
$containerName = "simpleblob"
New-AzStorageContainer -Name $containerName -Permission Blob -Context $ctx | Out-Null
Write-Host "Blob container created."

Write-Host "Adding blobs to container..."
Set-AzStorageBlobContent `
    -File "storage-template.json" `
    -Container $containerName `
    -Blob "storage-template.json" `
    -Context $ctx `
    | Out-Null
Set-AzStorageBlobContent `
    -File "storage-parameters.json" `
    -Container $containerName `
    -Blob "storage-parameters.json" `
    -Context $ctx `
    | Out-Null
Write-Host "Added blobs to container"

Write-Host "Listing all blobs in container"
Get-AzStorageBlob -Container $containerName -Context $ctx
Write-Host "Finished."