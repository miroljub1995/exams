$ErrorActionPreference = "Stop"

Write-Host "Logging in..."
If ((Get-AzContext) -eq $null) {Connect-AzAccount | Out-Null}
Write-Host "Logged in"

$location = "Switzerland North"
$adminUser = "miki"
$adminPassword = "Mydatabase1" | ConvertTo-SecureString -AsPlainText -Force
$serverName = "sql-server-$([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())"
$resourceGroupName = "database-rg"
$sqlDBName = "Company"

Write-Host "Creating group..."
New-AzResourceGroup -Name $resourceGroupName -Location $location | Out-Null
Write-Host "Group created"

Write-Host "Getting public IP..."
$clientIp = Invoke-WebRequest 'https://api.ipify.org' | Select-Object -ExpandProperty Content
Write-Host "Got public IP"

Write-Host "Creating database..."
New-AzResourceGroupDeployment `
    -ResourceGroupName $resourceGroupName `
    -TemplateFile ".\db-template.json" `
    -administratorLogin $adminUser `
    -administratorLoginPassword $adminPassword `
    -clientIP $clientIP `
    -serverName $serverName `
    -sqlDBName $sqlDBName `
    | Out-Null
Write-Host "Database created"

Write-Host "Creating elastic pool..."
$poolName = "elastic-pool"
New-AzResourceGroupDeployment `
    -ResourceGroupName $resourceGroupName `
    -TemplateFile ".\elastic-pool-template.json" `
    -poolName $poolName `
    -serverName $serverName `
    | Out-Null
Write-Host "Elastic pool created"

Write-Host "Adding database to pool..."
Set-AzSqlDatabase `
    -ResourceGroupName $resourceGroupName `
    -DatabaseName $sqlDBName `
    -ServerName $serverName `
    -ElasticPoolName $poolName `
    | Out-Null
Write-Host "DB added to pool"
