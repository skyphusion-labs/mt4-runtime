param location string = resourceGroup().location
param vmSize string = 'Standard_B2ms'
param adminUsername string = 'builder'
@secure()
param adminSshPublicKey string

var cloudInit = '''#cloud-config
package_update: true
packages:
  - docker.io
runcmd:
  - systemctl enable --now docker
'''

resource nsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: 'mt4-runtime-build-nsg'
  location: location
  properties: {
    securityRules: []
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: 'mt4-runtime-build-vnet'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.20.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'build'
        properties: {
          addressPrefix: '10.20.0.0/24'
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
    ]
  }
}

resource nic 'Microsoft.Network/networkInterfaces@2024-05-01' = {
  name: 'mt4-runtime-build-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipcfg'
        properties: {
          subnet: {
            id: '${vnet.id}/subnets/build'
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
    networkSecurityGroup: {
      id: nsg.id
    }
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: 'mt4-runtime-build'
  location: location
  tags: {
    purpose: 'mt4-runtime-build'
    ephemeral: 'true'
  }
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: 'mt4build'
      adminUsername: adminUsername
      customData: base64(cloudInit)
      linuxConfiguration: {
        disablePasswordAuthentication: true
        ssh: {
          publicKeys: [
            {
              path: '/home/${adminUsername}/.ssh/authorized_keys'
              keyData: adminSshPublicKey
            }
          ]
        }
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: 'ubuntu-24_04-lts'
        sku: 'server'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        diskSizeGB: 64
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: false
      }
    }
  }
}
