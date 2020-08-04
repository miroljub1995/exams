Connect-AzAccount
$rsaPath = "./id_rsa"
Start-Process -FilePath "ssh-keygen" -ArgumentList @("-m", "PEM", "-t", "rsa", "-b", "4096", "-f", "id_rsa", "-P", "linux") -Wait # try @("a","b") to "a","b"
$groupName = "vm-exam"
$location = "Switzerland North"
New-AzResourceGroup -Name $groupName -Location $location

# new subnet config
$subnetConfig = New-AzVirtualNetworkSubnetConfig `
  -Name "vm-subnet" `
  -AddressPrefix 10.0.0.0/24

# new virtual network
$vnet = New-AzVirtualNetwork `
  -ResourceGroupName $groupName `
  -Location $location `
  -Name "vm-vnet" `
  -AddressPrefix 10.0.0.0/16 `
  -Subnet $subnetConfig

# new public ip address
$pip = New-AzPublicIpAddress `
  -ResourceGroupName $groupName `
  -Location $location `
  -AllocationMethod Static `
  -IdleTimeoutInMinutes 4 `
  -Name "vm$(Get-Random)"
# save pip to file?

# allow ssh
$nsgRuleSSH = New-AzNetworkSecurityRuleConfig `
  -Name "vm-nsgRuleSSH"  `
  -Protocol "Tcp" `
  -Direction "Inbound" `
  -Priority 1000 `
  -SourceAddressPrefix * `
  -SourcePortRange * `
  -DestinationAddressPrefix * `
  -DestinationPortRange 22 `
  -Access "Allow"

# new network security group
$nsg = New-AzNetworkSecurityGroup `
  -ResourceGroupName $groupName `
  -Location $location `
  -Name "vm-nsg" `
  -SecurityRules $nsgRuleSSH

# new virtual network interface
$nic = New-AzNetworkInterface `
  -Name "vm-nic" `
  -ResourceGroupName $groupName `
  -Location $location `
  -SubnetId $vnet.Subnets[0].Id `
  -PublicIpAddressId $pip.Id `
  -NetworkSecurityGroupId $nsg.Id

# new credential object
$user = "linux"
$pass = "linux"
$securePassword = ConvertTo-SecureString $pass -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential ($user, $securePassword)

# new virtual machine configuration
$vmConfig = New-AzVMConfig `
  -VMName "vm" `
  -VMSize (Get-AzVMSize -Location $location | sort -Property "MemoryInMB")[0].Name | `
Set-AzVMOperatingSystem `
  -Linux `
  -ComputerName "vm" `
  -Credential $cred `
  -DisablePasswordAuthentication | `
Set-AzVMSourceImage `
  -PublisherName "Canonical" `
  -Offer "UbuntuServer" `
  -Skus "18.04-LTS" `
  -Version "latest" | `
Add-AzVMNetworkInterface `
  -Id $nic.Id

# new SSH key
$sshPublicKey = cat "$($rsaPath).pub"
Add-AzVMSshPublicKey `
  -VM $vmconfig `
  -KeyData $sshPublicKey `
  -Path "/home/$($user)/.ssh/authorized_keys"

# new vm
New-AzVM `
  -ResourceGroupName $groupName `
  -Location $location `
  -VM $vmConfig

# get public ip
$publicIp = (Get-AzPublicIpAddress -ResourceGroupName $groupName).IpAddress

# ssh to vm
Start-Process -FilePath "ssh" -ArgumentList "-i","id_rsa","$($user)@$($publicIp)" -Wait

# remove vm
Remove-AzResourceGroup -Name $groupName