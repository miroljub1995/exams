Import-Module -Name .\PSTest

Write-Host "1. Logging in..."
Connect-AzAccount

Write-Host "2. Showing subscriptions..."
Get-AzSubscription

Write-Host "3. Selecting subscription..."
Set-AzContext -SubscriptionName "Azure subscription 1"

Write-Host "4. Listing all VMs..."
Get-AzVM

Write-Host "5. Getting total vCPU resources utilization for a location..."
Get-AzVMUsage -Location "East US"

Write-Host "6. Listing all linux VMs"
Get-LinuxVM

Write-Host "7. Getting first linux VM..."
Get-FirstLinuxVM

Write-Host "8. Creating new VM..."
$newVM = New-VM

Write-Host "9. Removing newly created VM..."
Remove-VMWithDeps $newVM