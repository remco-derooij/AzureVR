@description('Username for the Virtual Machine.')
param AdminUser string = 'VRUser'


@description('Password for the Virtual Machine.')
@secure()
param AdminPassword string

@description('Location for all resources.')
param Location string = resourceGroup().location

@description('Your external IP for NSG access.')
param extIP string

@description('Allow ICMP on NSG from extIP')
@allowed(
  [
   'Allow'
   'Block'
  ])
param icmprule string = 'Allow'

@description('VMSize for VM.')
@allowed([
  'Standard_NC6_Promo'
  'Standard_NC6'
  'Standard_NV6_Promo'
  'Standard_NV6'
])
param vmSize string = 'Standard_NC6_Promo'


@description('Computername for VM.')
param vmName string = 'AzureVRVM01'

@description('Computername for vNIC.')
param nicname string = 'AzureVRnic01'

@description('Name for Virtual Network.')
param vNetName string = 'AzureVRvNet'

@description('Name for Subnet.')
param subnetName string = 'AzureVRSubnet'

@description('Address for vNet.')
param addressPrefix string = '10.0.0.0/16'

@description('Address for subnet.')
param subnetPrefix string = '10.0.0.0/24'

@description('Name for PublicIP.')
param PublicIPName string = 'AzureVRPiP'

@description('Name for Network Security Group')
param networkSecurityGroupName string = 'AzureVRNSG'



resource VirtualNetwork 'Microsoft.Network/virtualNetworks@2019-11-01' = {
  name: vNetName
  location: Location
  properties: {
    addressSpace: {addressPrefixes: [addressPrefix]}
    subnets: [
      {
        name: subnetName
        properties: { addressPrefix: subnetPrefix
        networkSecurityGroup: {id: NetworkSecurityGroup.id} }
      }
    ]
  }
}

resource NetworkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2019-11-01' = {
  name: networkSecurityGroupName
  location: Location
  properties: {
    securityRules: [
      {
        name: 'rule-allow-RDP'
        properties: {
          description: 'RULE-ALLOW-RDP'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3389'
          sourceAddressPrefix: extIP
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 150
          direction: 'Inbound'
        }
      }
      {
        name: 'rule-allow-ICMP'
        properties: {
          description: 'RULE-ALLOW-ICMP'
          protocol: 'Icmp'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: extIP
          destinationAddressPrefix: '*'
          access: icmprule
          priority: 160
          direction: 'Inbound'
        }
      }
    ]
  }
}


resource VirtualNIC 'Microsoft.Network/networkInterfaces@2022-05-01' = {
  name: nicname
  location: Location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          publicIPAddress: {id: PublicIP.id}
          privateIPAllocationMethod: 'Dynamic'
          subnet: {id: resourceId('Microsoft.Network/virtualNetworks/subnets', VirtualNetwork.name, subnetName)
        }
        }
      }
    ]
  }
}



resource PublicIP 'Microsoft.Network/publicIPAddresses@2022-05-01' = {
  name: PublicIPName
  location: Location
  sku: {name: 'Basic'}
}



resource VirtualMachine 'Microsoft.Compute/virtualMachines@2020-12-01' = {
  name: vmName
  location: Location
  properties: {
    hardwareProfile: {vmSize: vmSize}
    osProfile: {
      computerName: vmName
      adminUsername: AdminUser
      adminPassword: AdminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsDesktop'
        offer: 'Windows-10'
        sku: 'win10-21h2-pro'
        version: 'latest'
        }
      osDisk: {
        managedDisk: {storageAccountType: 'StandardSSD_LRS'}
        createOption: 'FromImage'
      }
    }
    networkProfile: {networkInterfaces: [{id: VirtualNIC.id}]}
  }
}


resource NvidiaGpuDriverWindows 'Microsoft.Compute/virtualMachines/extensions@2022-08-01' = {
  name: 'NvidiaGpuDriverWindows'
  parent: VirtualMachine
  location: Location
  properties: {
    publisher: 'Microsoft.HpcCompute'
    type: 'NvidiaGpuDriverWindows'
    typeHandlerVersion: '1.2'
    autoUpgradeMinorVersion: true
    settings: {}
   }
}
