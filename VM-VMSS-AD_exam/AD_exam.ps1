Connect-AzAccount

$appName = "SimbpleApp"
$certLocation = "cert:\CurrentUser\My"
$certSubject = "CN=$($appName)ScriptCert"

Get-ChildItem $certLocation | Where-Object {$_.Subject -eq $certSubject } | Select-Object -Property PSPath | Remove-Item
$cert = New-SelfSignedCertificate -CertStoreLocation $certLocation `
  -Subject $certSubject `
  -KeySpec KeyExchange
$keyValue = [System.Convert]::ToBase64String($cert.GetRawCertData())

$sp = New-AzADServicePrincipal -DisplayName $appName `
  -CertValue $keyValue `
  -EndDate $cert.NotAfter `
  -StartDate $cert.NotBefore

Sleep 20
New-AzRoleAssignment -RoleDefinitionName Contributor -ServicePrincipalName $sp.ApplicationId

$TenantId = (Get-AzSubscription -SubscriptionName "Azure subscription 1").TenantId
$ApplicationId = (Get-AzADApplication -DisplayName $appName).ApplicationId

$Thumbprint = (Get-ChildItem $certLocation | Where-Object {$_.Subject -eq $certSubject }).Thumbprint

Get-AzContext | Disconnect-AzAccount
Connect-AzAccount -ServicePrincipal `
  -CertificateThumbprint $Thumbprint `
  -ApplicationId $ApplicationId `
  -TenantId $TenantId

Get-AzResource