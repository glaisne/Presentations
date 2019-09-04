


#-----------------------------
# Variables
#-----------------------------

# Subscription info
$SubscriptionName = 'Azure-ITInfra-Dev'

# Resource Group Info
$Attempt = 'a'
$purpose = 'Postmortum on Azu-mgmt-prod' # removed the etag
$location = 'East US'

# Template info
$TemplateFile = "$pwd\azuredeploy.json"

# Template Parameters
$rgname = "postmortum01-rg" # working on better OUs & Autoshutdown
$saname = "postmortomas"     # Lowercase required
$VMName = 'PMOrigOSDisk' # Windows computer name cannot be more than 15 characters long, be entirely numeric, or contain the following characters: ` ~ ! @ # $ % ^ & * ( ) = + _ [ ] { } \ | ; : . ' " , < > / ?
$OsType = 'Windows'
$osDiskVhdUri = 'https://postmortomas.blob.core.windows.net/vhds03/AZU-MGMT-Prod-AZU-MGMT-Prod-2014-07-28.vhd'
$vmSize = 'Standard_D2_v2'
$existingVirtualNetworkName = 'postmortum-vnet'
$existingVirtualNetworkResourceGroup = $rgname
$diagStorageAccountName = $saname
$subnetName = 'postmortum-subnet'


# if ($keyVaultName -notmatch '^[a-zA-Z0-9-]{3,24}$')
# {
#     Throw "The keyVaultName odes not match the pattern '^[a-zA-Z0-9-]{3,24}$'"
# }

if ($VMName.length -gt 15)
{
    Throw "VMName ($VMName) is longer than 15 characters."
}

#-----------------------------
# Functions
#-----------------------------


#-----------------------------
# Main
#-----------------------------


#
#    Setup Azure Environment
#


# Import AzureRM modules for the given version manifest in the AzureRM module
if (-not $(get-module AzureRm))
{
    Import-Module AzureRm -Verbose
}

# Authenticate to your Azure account
# Login-AzureRmAccount

Select-AzureRmSubscription -SubscriptionName $SubscriptionName

# Create the new resource group.
if (-not [string]::isnullorempty($purpose))
{
    New-AzureRmResourceGroup -Name $rgname -Location $Location -Verbose -Tag @{purpose = $purpose}
}
else
{
    New-AzureRmResourceGroup -Name $rgname -Location $Location -Verbose 
}


#
#    Setup Arm Template
#


# Parameters for the template and configuration
$MyParams = @{
    # storageAccount_name = $saname
    location       = $location
    vmName         = $VMName
    osType         = $OsType
    osDiskVhdUri   = $osDiskVhdUri
    vmSize         = $vmSize
    existingVirtualNetworkName = $existingVirtualNetworkName
    existingVirtualNetworkResourceGroup = $existingVirtualNetworkResourceGroup
    diagStorageAccountName = $diagStorageAccountName
    subnetName = $subnetName
}


# Splat the parameters on New-AzureRmResourceGroupDeployment
$SplatParams = @{
    TemplateFile            = $TemplateFile
    ResourceGroupName       = $rgname
    TemplateParameterObject = $MyParams
    Name                    = 'PostMortum'
}

# test first

$TestParams = $splatParams
$TestParams.Remove('Name')
# $TestParams.Remove('adminPassword')

$global:results = Test-AzureRmResourceGroupDeployment @TestParams -Verbose

$Global:results |fl * -force


# One prompt for the domain admin password
try
{
    New-AzureRmResourceGroupDeployment @SplatParams -Verbose -DeploymentDebugLogLevel All -ErrorAction Stop
}
catch
{
    throw $_
}

