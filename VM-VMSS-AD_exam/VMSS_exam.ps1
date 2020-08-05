Connect-AzAccount

$vmssGroupName = "vmss-exam"
$location = "Switzerland North"
$scaleSetName = "vmss"
New-AzResourceGroup -ResourceGroupName $vmssGroupName -Location $location

# setup image gallery
$sourceVM = Get-AzVM `
   -Name "vm" `
   -ResourceGroupName "vm-exam"

$gallery = New-AzGallery `
   -GalleryName 'vmssGallery' `
   -ResourceGroupName $vmssGroupName `
   -Location $location `
   -Description 'Shared Image Gallery'

$galleryImage = New-AzGalleryImageDefinition `
   -GalleryName $gallery.Name `
   -ResourceGroupName $vmssGroupName `
   -Location $location `
   -Name 'vmssImageDefinition' `
   -OsState specialized `
   -OsType Linux `
   -Publisher 'vmssPublisher' `
   -Offer 'vmssOffer' `
   -Sku 'vmssSku'

New-AzGalleryImageVersion `
   -GalleryImageDefinitionName $galleryImage.Name`
   -GalleryImageVersionName '1.0.0' `
   -GalleryName $gallery.Name `
   -ResourceGroupName $vmssGroupName `
   -Location $location `
   -TargetRegion @{Name=$location;ReplicaCount=2}  `
   -Source $sourceVM.Id.ToString() `
   -PublishingProfileEndOfLifeDate '2021-12-01'
########################

# new virtual network
$subnet = New-AzVirtualNetworkSubnetConfig `
  -Name "vmss-subnet" `
  -AddressPrefix 10.0.0.0/24
$vnet = New-AzVirtualNetwork `
  -ResourceGroupName $vmssGroupName `
  -Name "vmss-vnet" `
  -Location $location `
  -AddressPrefix 10.0.0.0/16 `
  -Subnet $subnet
$publicIP = New-AzPublicIpAddress `
  -ResourceGroupName $vmssGroupName `
  -Location $location `
  -AllocationMethod Static `
  -Name "vmss-$(Get-Random)"
################

# setup load balancer
$frontendIP = New-AzLoadBalancerFrontendIpConfig `
  -Name "vmss-frontEndPool" `
  -PublicIpAddress $publicIP

$backendPool = New-AzLoadBalancerBackendAddressPoolConfig -Name "vmss-backEndPool"

# enable ssh on instances
$inboundNATPool = New-AzLoadBalancerInboundNatPoolConfig `
  -Name "myRDPRule" `
  -FrontendIpConfigurationId $frontendIP.Id `
  -Protocol TCP `
  -FrontendPortRangeStart 50001 `
  -FrontendPortRangeEnd 50010 `
  -BackendPort 22

# Create the load balancer
$lb = New-AzLoadBalancer `
  -ResourceGroupName $vmssGroupName `
  -Name "vmss-loadBalancer" `
  -Location $location `
  -FrontendIpConfiguration $frontendIP `
  -BackendAddressPool $backendPool `
  -InboundNatPool $inboundNATPool

# this is for opening http port
#Add-AzLoadBalancerProbeConfig -Name "vmss-healthProbe" `
#  -LoadBalancer $lb `
#  -Protocol TCP `
#  -Port 80 `
#  -IntervalInSeconds 15 `
#  -ProbeCount 2

#Add-AzLoadBalancerRuleConfig `
#  -Name "vmss-loadBalancerRule" `
#  -LoadBalancer $lb `
#  -FrontendIpConfiguration $lb.FrontendIpConfigurations[0] `
#  -BackendAddressPool $lb.BackendAddressPools[0] `
#  -Protocol TCP `
#  -FrontendPort 80 `
#  -BackendPort 80 #`
#  -Probe (Get-AzLoadBalancerProbeConfig -Name "vmss-healthProbe" -LoadBalancer $lb)

#Set-AzLoadBalancer -LoadBalancer $lb
#############################

# Create IP address configurations
$ipConfig = New-AzVmssIpConfig `
  -Name "vmss-ipConfig" `
  -LoadBalancerBackendAddressPoolsId $lb.BackendAddressPools[0].Id `
  -LoadBalancerInboundNatPoolsId $inboundNATPool.Id `
  -SubnetId $vnet.Subnets[0].Id

# Create a configuration 
$vmssConfig = New-AzVmssConfig `
    -Location $location `
    -SkuCapacity 1 `
    -SkuName "Standard_B1ls" `
    -UpgradePolicyMode "Automatic"

# Reference the image version
Set-AzVmssStorageProfile $vmssConfig `
  -OsDiskCreateOption "FromImage" `
  -ImageReferenceId $galleryImage.Id

# Complete the configuration
Add-AzVmssNetworkInterfaceConfiguration `
  -VirtualMachineScaleSet $vmssConfig `
  -Name "vmss-netConfig" `
  -Primary $true `
  -IPConfiguration $ipConfig 

# Create the scale set 
New-AzVmss `
  -ResourceGroupName $vmssGroupName `
  -Name $scaleSetName `
  -VirtualMachineScaleSet $vmssConfig

$publicIp = (Get-AzPublicIpAddress -ResourceGroupName $vmssGroupName).IpAddress

Start-Process -FilePath "ssh" -ArgumentList "-i","id_rsa","linux@$($publicIp)","-p","50001" -Wait

# setup auto scale
$vmss = Get-AzVmss -ResourceGroupName $vmssGroupName -VMScaleSetName vmss

$vmssRuleScaleOut = New-AzAutoscaleRule `
  -MetricName "Percentage CPU" `
  -MetricResourceId $vmss.Id `
  -TimeGrain 00:01:00 `
  -MetricStatistic "Average" `
  -TimeWindow 00:05:00 `
  -Operator "GreaterThan" `
  -Threshold 50 `
  -ScaleActionDirection "Increase" `
  -ScaleActionScaleType "ChangeCount" `
  -ScaleActionValue 1 `
  -ScaleActionCooldown 00:05:00

$vmssRuleScaleIn = New-AzAutoscaleRule `
  -MetricName "Percentage CPU" `
  -MetricResourceId $vmss.Id `
  -Operator "LessThan" `
  -MetricStatistic "Average" `
  -Threshold 10 `
  -TimeGrain 00:01:00 `
  -TimeWindow 00:05:00 `
  -ScaleActionCooldown 00:05:00 `
  -ScaleActionDirection "Decrease" `
  -ScaleActionScaleType "ChangeCount" `
  -ScaleActionValue 1

$vmssScaleProfile = New-AzAutoscaleProfile `
  -DefaultCapacity 1  `
  -MaximumCapacity 2 `
  -MinimumCapacity 1 `
  -Rule $vmssRuleScaleOut,$vmssRuleScaleIn `
  -Name "autoprofile" 

$currAutoScaleSetting = (Get-AzAutoscaleSetting -ResourceGroupName $vmssGroupName)[0]
Remove-AzAutoscaleSetting -ResourceGroupName $vmssGroupName -Name $currAutoScaleSetting.Name

Add-AzAutoscaleSetting `
  -Location $location `
  -TargetResourceId $vmss.Id `
  -Name "autoscalesettings" `
  -ResourceGroupName $vmssGroupName `
  -AutoscaleProfile $vmssScaleProfile

# perform stress into one vm
Start-Process -FilePath "ssh" -ArgumentList "-i","id_rsa","linux@$($publicIp)","-p","50001","sudo apt update && sudo apt install stress && stress --cpu 1"

while (1) {(Get-AzVmssVM `
    -ResourceGroupName $vmssGroupName `
    -VMScaleSetName $vmss.Name).Length; sleep 10}

#Remove-AzResourceGroup -Name $vmssGroupName