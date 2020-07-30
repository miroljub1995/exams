Import-Module Az

Function Get-LinuxVM {
    [OutputType([Microsoft.Azure.Commands.Compute.Models.PSVirtualMachine])]
    param ()
    Get-AzVM | Where-Object {$_.StorageProfile.OsDisk.OsType -eq "Linux"}
}
Get-LinuxVM

Function Get-FirstLinuxVM {
    [OutputType([Microsoft.Azure.Commands.Compute.Models.PSVirtualMachine])]
    param ()
    return Get-LinuxVM | sort Name | Select -First 1
}

Function Get-PSPublicAddressFromId {
    [OutputType([Microsoft.Azure.Commands.Network.Models.PSPublicIpAddress])]
    param (
        [string]$Id
    )
    $resource = Get-AzResource -ResourceId $Id
    $publicIpName = $resource.Name
    $publicIpResourceGroupName = $resource.ResourceGroupName
    return (Get-AzPublicIpAddress -Name $publicIpName -ResourceGroupName $publicIpResourceGroupName)
}

Function Get-PSVirtualNetworkFromId {
    [OutputType([Microsoft.Azure.Commands.Network.Models.PSVirtualNetwork])]
    param (
        [string]$Id
    )
    $resource = Get-AzResource -ResourceId $Id
    $name = $resource.Name
    $resourceGroupName = $resource.ResourceGroupName
    return (Get-AzVirtualNetwork -ResourceGroupName $resourceGroupName -Name $name)
}

Function Get-PSNetSecurityGroupFromId {
    [OutputType([Microsoft.Azure.Commands.Network.Models.PSNetworkSecurityGroup])]
    param (
        [string]$Id
    )
    $resource = Get-AzResource -ResourceId $Id
    $name = $resource.Name
    $resourceGroupName = $resource.ResourceGroupName
    return Get-AzNetworkSecurityGroup -ResourceGroupName $resourceGroupName -Name $name
}

Function New-PublicIpFromModel {
    [OutputType([Microsoft.Azure.Commands.Network.Models.PSPublicIpAddress])]
    param (
        [Microsoft.Azure.Commands.Network.Models.PSPublicIpAddress]$PublicIp
    )
    $name = $PublicIp.Name
    $newName = "$($name)_copy"
    $resourceGroupName = $PublicIp.ResourceGroupName
    $path = "./$($Name)-template.json"
    Export-AzResourceGroup -ResourceGroupName $resourceGroupName -Resource $PublicIp.Id -Path $path | Out-Host
    $params = @{
        "publicIPAddresses_$($name -replace "-", "_")_name" = $newName
    }
    New-AzResourceGroupDeployment -ResourceGroupName $resourceGroupName -TemplateFile $path -TemplateParameterObject $params | Out-Host
    Remove-Item -Path $path
    return (Get-AzPublicIpAddress -ResourceGroupName $resourceGroupName -Name $newName)
}

Function New-VirtualNetFromModel {
    [OutputType([Microsoft.Azure.Commands.Network.Models.PSVirtualNetwork])]
    param (
        [Microsoft.Azure.Commands.Network.Models.PSVirtualNetwork]$VirtualNet
    )
    $name = $VirtualNet.Name
    $newName = "$($name)_copy"
    $resourceGroupName = $VirtualNet.ResourceGroupName
    $path = "./$($name)-template.json"
    Export-AzResourceGroup -ResourceGroupName $resourceGroupName -Resource $VirtualNet.Id -Path $path | Out-Host
    $params = @{
        "virtualNetworks_$($name -replace "-", "_")_name" = $newName
    }
    New-AzResourceGroupDeployment -ResourceGroupName $resourceGroupName -TemplateFile $path -TemplateParameterObject $params | Out-Host
    Remove-Item -Path $path
    return (Get-AzVirtualNetwork -ResourceGroupName $resourceGroupName -Name $newName)
}

Function New-NetworkSecutiryGroupFromModel {
    [OutputType([Microsoft.Azure.Commands.Network.Models.PSNetworkSecurityGroup])]
    param (
        [Microsoft.Azure.Commands.Network.Models.PSNetworkSecurityGroup]$Nsg
    )
    $name = $Nsg.Name
    $newName = "$($name)_copy"
    $resourceGroupName = $Nsg.ResourceGroupName
    $path = "./$($name)-template.json"
    Export-AzResourceGroup -ResourceGroupName $resourceGroupName -Resource $Nsg.Id -Path $path | Out-Host
    $params = @{
        "networkSecurityGroups_$($name -replace "-", "_")_name" = $newName
    }
    New-AzResourceGroupDeployment -ResourceGroupName $resourceGroupName -TemplateFile $path -TemplateParameterObject $params | Out-Host
    Remove-Item -Path $path
    return (Get-AzNetworkSecurityGroup -ResourceGroupName $resourceGroupName -Name $newName)
}

Function New-NetworkInterfaceFromModel {
    [OutputType([Microsoft.Azure.Commands.Network.Models.PSNetworkInterface])]
    param (
        [Microsoft.Azure.Commands.Network.Models.PSNetworkInterface]$NetInterface
    )
    $id = $NetInterface.Id
    $name = $NetInterface.Name
    $newName = "$($name)_copy"
    $resourceGroupName = $NetInterface.ResourceGroupName
    $params = @{
        "networkInterfaces_$($name -replace "-", "_")_name" = $newName
    }

    $ipConfigs = @($NetInterface.IpConfigurations)
    For ($i=0; $i -lt $ipConfigs.Length; $i++) {
        $ipConfig = $ipConfigs[$i]
        $publicIpId = $ipConfig.PublicIpAddress.Id
        $publicIp = Get-PSPublicAddressFromId -Id $publicIpId
        $newPublicIp = New-PublicIpFromModel -PublicIp $publicIp
        $params["publicIPAddresses_$($publicIp.Name -replace "-", "_")_externalid"] = $newPublicIp.Id

        $vNetId = $ipConfig.Subnet.Id -replace ".subnets/default"
        $vNet = Get-PSVirtualNetworkFromId -Id $vNetId
        $newVNet = New-VirtualNetFromModel -VirtualNet $vNet
        $params["virtualNetworks_$($vNet.Name -replace "-", "_")_externalid"] = $newVNet.Id
    }

    $netSecurityGroupId = $NetInterface.NetworkSecurityGroup.Id
    $netSecurityGroup = Get-PSNetSecurityGroupFromId -Id $netSecurityGroupId
    $newNetSecurityGroup =  New-NetworkSecutiryGroupFromModel -Nsg $netSecurityGroup
    $params["networkSecurityGroups_$($netSecurityGroup.Name -replace "-", "_")_externalid"] = $newNetSecurityGroup.Id

    $path = "./$($name)-template.json"
    Export-AzResourceGroup -ResourceGroupName $resourceGroupName -Resource $id -Path $path | Out-Host
    New-AzResourceGroupDeployment -ResourceGroupName $resourceGroupName -TemplateFile $path -TemplateParameterObject $params | Out-Host
    Remove-Item -Path $path
    return (Get-AzNetworkInterface -ResourceGroupName $resourceGroupName -Name $newName)
}

Function Update-VMTemplate {
    param (
        [Microsoft.Azure.Commands.Compute.Models.PSVirtualMachine]$VM
    )
    $name = $VM.Name
    $path = "./$($name)-template.json"
    $template = Get-Content -Path $path -Raw | ConvertFrom-Json
    $template.resources.properties.storageProfile.osDisk.managedDisk.PSObject.Properties.Remove("id")
    $template.resources.properties.osProfile.PSObject.Properties.Remove("requireGuestProvisionSignal")
    $template.parameters.PSObject.Properties.Remove("disks_$($VM.StorageProfile.OsDisk.Name)_externalid")
    $template | ConvertTo-Json -Depth 100 | Out-File $path
}

Function New-VM {
    [Microsoft.Azure.Commands.Compute.Models.PSVirtualMachine]$vmModel = Get-FirstLinuxVM
    $id = $vmModel.Id
    $name = $vmModel.Name
    $newName = "$($name)Copy"
    $resourceGroupName = $vmModel.ResourceGroupName
    $params = @{
        "virtualMachines_$($name)_name" = $newName
    }

    $netInterfaceIds = @($vmModel.NetworkProfile.NetworkInterfaces | ForEach-Object {$_.Id})
    For ($i=0; $i -lt $netInterfaceIds.Length; $i++) {
        $netInterfaceId = $netInterfaceIds[$i]
        $netInterface = Get-AzNetworkInterface -ResourceId $netInterfaceId
        $newNetInterface = (New-NetworkInterfaceFromModel -NetInterface $netInterface)
        $netInterfaceName = $netInterface.Name
        $params["networkInterfaces_$($netInterfaceName)_externalid"] = $newNetInterface.Id
    }

    $path = "./$($name)-template.json"
    Export-AzResourceGroup -ResourceGroupName $resourceGroupName -Resource $id -Path $path | Out-Host
    Update-VMTemplate -VM $vmModel | Out-Host
    New-AzResourceGroupDeployment -ResourceGroupName $resourceGroupName -TemplateFile $path -TemplateParameterObject $params | Out-Host
    Remove-Item -Path $path
    return (Get-AzVM -ResourceGroupName $resourceGroupName -Name $newName)
}

Function Remove-NetInterfaceDeep {
    param (
        [Microsoft.Azure.Commands.Network.Models.PSNetworkInterface]$NetInterface
    )
    Remove-AzResource -ResourceId $NetInterface.Id | Out-Host
    $ipConfigs = @($NetInterface.IpConfigurations)
    For ($i=0; $i -lt $ipConfigs.Length; $i++) {
        $ipConfig = $ipConfigs[$i]
        Remove-AzResource -ResourceId $ipConfig.PublicIpAddress.Id | Out-Host
        Remove-AzResource -ResourceId ($ipConfig.Subnet.Id -replace ".subnets/default") | Out-Host
    }
    Remove-AzResource -ResourceId $NetInterface.NetworkSecurityGroup.Id | Out-Host
}

Function Remove-VMWithDeps {
    param (
        [Microsoft.Azure.Commands.Compute.Models.PSVirtualMachine]$VM
    )
    Stop-AzVM -Id $VM.Id
    Remove-AzResource -ResourceId $VM.Id | Out-Host
    Remove-AzResource -ResourceId $VM.StorageProfile.OsDisk.ManagedDisk.Id | Out-Host
    $netInterfaceIds = @($VM.NetworkProfile.NetworkInterfaces | ForEach-Object {$_.Id})
    For ($i=0; $i -lt $netInterfaceIds.Length; $i++) {
        $netInterfaceId = $netInterfaceIds[$i]
        $netInterface = Get-AzNetworkInterface -ResourceId $netInterfaceId
        Remove-NetInterfaceDeep -NetInterface $netInterface
    }
}

Export-ModuleMember -Function Get-LinuxVM, Get-FirstLinuxVM, New-VM, Remove-VMWithDeps