Import-Module -Name ..\Utils
Initialize-Shell
Check-Login

Write-Host "Creating resource group..."
$resourceGroupName = "exam6"
$location = "switzerlandnorth"
New-AzResourceGroup -Name $resourceGroupName -Location $location | Out-Null
Write-Host "Resource group created."

Write-Host "Creating KeyVault..."
$vaultName = "SimpleVault-$(Get-UnixTimeSeconds)"
New-AzResourceGroupDeployment -ResourceGroupName $resourceGroupName -TemplateFile .\kv-template.json -TemplateParameterFile .\kv-parameters.json -vaultName $vaultName | Out-Null
Write-Host "KeyVault created."

Write-Host "Adding key to KV..."
$keyName = "SimpleKey-$(Get-UnixTimeSeconds)"
Add-AzKeyVaultKey -Destination Software -Name $keyName -VaultName $vaultName | Out-Null
Write-Host "Key added to vault."

Write-Host "Adding secret to KV..."
$secretvalue = ConvertTo-SecureString 'thisissecret' -AsPlainText -Force
$secretName = "SimpleSecret-$(Get-UnixTimeSeconds)"
$secret = Set-AzKeyVaultSecret -VaultName $vaultName -Name $secretName -SecretValue $secretvalue
Write-Host "Secret added to KV."

Write-Host "Adding cert to KV..."
$certSubject = "CN=simpleAppCert"
$certLocation = "cert:\CurrentUser\My"
Get-ChildItem $certLocation | Where-Object {$_.Subject -eq $certSubject } | Select-Object -Property PSPath | Remove-Item | Out-Null
$cert = New-SelfSignedCertificate -CertStoreLocation $certLocation `
  -Subject $certSubject `
  -KeySpec KeyExchange
$keyValue = [System.Convert]::ToBase64String($cert.GetRawCertData())
$certName = "SimpleCert-$(Get-UnixTimeSeconds)"
#Import-AzKeyVaultCertificate -CertificateString $keyValue -Name $certName -VaultName $vaultName | Out-Null
#Write-Host "Cert added to vault"

Write-Host "Creating new service principal..."
$servicePrincipalName = "SimpleApp1"
$sp = New-AzADServicePrincipal -DisplayName $servicePrincipalName -Role Contributor
sleep -Seconds 20
Write-Host "New service principal created."

Write-Host "Adding get access to service principal for vault..."
Set-AzKeyVaultAccessPolicy `
    -ResourceGroupName $resourceGroupName `
    -VaultName $vaultName `
    -ObjectId $sp.Id `
    -PermissionsToKeys get `
    -PermissionsToCertificates get `
    -PermissionsToSecrets get
Write-Host "Added get access to service principal for vault"

Write-Host "Connecting as new principal..."
$tenantId = (Get-AzContext).Tenant.Id
$subscriptionId = (Get-AzSubscription).Id
$pscredential = New-Object -TypeName System.Management.Automation.PSCredential($sp.ApplicationId, $sp.Secret)
Connect-AzAccount -ServicePrincipal -Credential $pscredential -Tenant $tenantId -Subscription $subscriptionId
Write-Host "Connected as new principal."

Write-Host "Trying some access..."
Get-AzKeyVaultKey -VaultName $vaultName -Name $keyName
Write-Host "Completed."