import-module AzureRm
login-AzureRmAccount

# Create VM ------------------------------------------------------------------------------------------------------------------------------
$ResourceGroup = 'VMDemo'
$Location      = 'East US'

# This script requires these Resource Providers
#  * Microsoft.Network
#  * Microsoft.Compute
if (-Not (Get-AzureRmResourceProvider -ProviderNamespace Microsoft.Network))
{
    Register-AzureRmResourceProvider -ProviderNamespace Microsoft.Network
}

if (-Not (Get-AzureRmResourceProvider -ProviderNamespace Microsoft.Compute))
{
    Register-AzureRmResourceProvider -ProviderNamespace Microsoft.Compute
}

# Create the Resource Group
New-AzureRmResourceGroup -Name $ResourceGroup -Location $Location


## NSG
# Create an inbound network security group rule for port 3389
# Priority: Small number = higher priority
$nsgRuleRDP = New-AzureRmNetworkSecurityRuleConfig -Name myNetworkSecurityGroupRuleRDP  -Protocol Tcp `
    -Direction Inbound -Priority 1000 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * `
    -DestinationPortRange 3389 -Access Allow

# Create a network security group
$nsg = New-AzureRmNetworkSecurityGroup -ResourceGroupName $ResourceGroup -Location $Location `
    -Name 'myNetworkSecurityGroup' -SecurityRules $nsgRuleRDP

## Network
# Create a subnet configuration
$subnetConfig = New-AzureRmVirtualNetworkSubnetConfig -Name mySubnet -AddressPrefix 192.168.1.0/24

# Create a virtual network
$vnet = New-AzureRmVirtualNetwork -ResourceGroupName $ResourceGroup -Location $Location `
    -Name MYvNET -AddressPrefix 192.168.0.0/16 -Subnet $subnetConfig

# Create a public IP address and specify a DNS name
$pip = New-AzureRmPublicIpAddress -ResourceGroupName $ResourceGroup -Location $Location `
    -AllocationMethod Static -IdleTimeoutInMinutes 4 -Name "mypublicdns$(Get-Random)"

# Create a virtual network card and associate with public IP address and NSG
$nic = New-AzureRmNetworkInterface -Name myNic -ResourceGroupName $ResourceGroup -Location $Location `
    -SubnetId $vnet.Subnets[0].Id -PublicIpAddressId $pip.Id -NetworkSecurityGroupId $nsg.Id

# Define a credential object
$cred = Get-Credential -UserName 'Gene' -Message 'Credentials for your new VM'

# Create a virtual machine configuration
$vmConfig = New-AzureRmVMConfig -VMName myVM -VMSize Standard_DS1 | `
    Set-AzureRmVMOperatingSystem -Windows -ComputerName myVM -Credential $cred | `
    Set-AzureRmVMSourceImage -PublisherName MicrosoftWindowsServer -Offer WindowsServer `
    -Skus '2016-Datacenter' -Version latest | Add-AzureRmVMNetworkInterface -Id $nic.Id

# Create the Virtual Machine
New-AzureRmVM -ResourceGroupName $ResourceGroup -Location $Location -VM $vmConfig    

# remove the server
mstsc /v:$($pip.ipAddress)

# Create Web App -------------------------------------------------------------------------------------------------------------------------

$ResourceGroup = 'WebAppDemo'
$WebAppName    = "MyWebAppDemo$(get-random -min 1000 -max 9999)"
$Location      = 'East Us'


# Create a resource group
New-AzureRmResourceGroup -Name $ResourceGroup -Location $Location

# Create App Service Plan
# - Service plan defines the type of system to be used and groups web apps together.
# - 'Standard' Tier to alow for additional 'slots'
New-AzureRmAppServicePlan -Name 'MyAppServicePlan01' -Location $Location -Tier 'Standard' -ResourceGroupName $ResourceGroup 

# Create a Web App
New-AzureRmWebApp -ResourceGroupName $ResourceGroup -Name $WebAppName -location $Location  -AppServicePlan 'MyAppServicePlan01'

# Create a 'Staging' deployment slot
New-AzureRmWebAppSlot -name $WebAppName -ResourceGroupName $ResourceGroup -Slot 'Staging'

# Publish my page to the staging slot.
# - The zip file is a zipped index.html file in this case.
Publish-AzureWebsiteProject -Package 'C:\data\BAWSUG\LoadFest - 2016 - November\index.zip' -Name $WebAppName -Slot 'Staging'

# View the 'production' page:
Start-Process "http://$($WebAppName)`.azurewebsites.net/"

# View the 'Staging' page:
Start-Process "http://$($WebAppName)-staging.azurewebsites.net/"

# Swap staging for production
Swap-AzureRmWebAppSlot -Name $WebAppName -ResourceGroupName $ResourceGroup -SourceSlotName 'Staging' -DestinationSlotName 'Production'

# View the 'production' page:
Start-Process "http://$($WebAppName)`.azurewebsites.net/"

# View the 'Staging' page:
Start-Process "http://$($WebAppName)-staging.azurewebsites.net/"


# Create SQL Database ----------------------------------------------------------------------------------------------------------------------

# The data center and resource name for your resources
$resourcegroupname = "myResourceGroup"
$location = "East Us"
# The logical server name: Use a random value or replace with your own value (do not capitalize)
$servername = "server-$(Get-Random)"
# Set an admin login and password for your database
# The login information for the server
$adminlogin = "ServerAdmin"
$password = "ChangeYourAdminPassword1"
# The database name
$databasename = "AdventureWorksLT"


New-AzureRmResourceGroup -Name $resourcegroupname -Location $location

# may need to register Microsoft.sql
# Register-AzureRmResourceProvider -ProviderNamespace Microsoft.sql

New-AzureRmSqlServer -ResourceGroupName $resourcegroupname `
    -ServerName $servername `
    -Location $location `
    -SqlAdministratorCredentials $([System.Management.Automation.PSCredential]::new($adminlogin, $(ConvertTo-SecureString -String $password -AsPlainText -Force)))

# Create the Sql Database.
# Here, we're populating the database with the AdventureWorksLT sample database
# SQL Database service tier (-RequestedServiceObjectiveName)
# https://docs.microsoft.com/en-us/azure/sql-database/sql-database-service-tiers
New-AzureRmSqlDatabase  -ResourceGroupName $resourcegroupname `
    -ServerName $servername `
    -DatabaseName $databasename `
    -SampleName "AdventureWorksLT" `
    -RequestedServiceObjectiveName "S0" # Standard tier level 0

# on the system with the required SQL software to query
$publicIp = (Invoke-WebRequest http://myexternalip.com/raw).Content -replace "`n"


# Steps for querying the database.
# See: https://4sysops.com/archives/how-to-query-an-azure-sql-database-with-powershell/

