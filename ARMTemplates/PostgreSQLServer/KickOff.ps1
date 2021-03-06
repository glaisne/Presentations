
param (
    [string]
    $Attempt,

    [string]
    $purpose
)


#-----------------------------
# Variables
#-----------------------------


$SubscriptionName = 'Visual Studio Enterprise'
$SubscriptionName = 'Azure-Powershell-ITDev'

if (-not ($PSBoundParameters.ContainsKey('Attempt')))
{
    $Attempt = 'd'
}


if (-not ($PSBoundParameters.ContainsKey('purpose')))
{
    $purpose = 'PostgreSQL Restore RBAC' # removed the etag
}

$TemplateFile = "$pwd\azuredeploy.json"
$rgname = "PostgreSQL$Attempt" # working on better OUs & Autoshutdown
#$saname = "genesyssa$Attempt"     # Lowercase required
$VMName = 'MyUbuntuVM' # Windows computer name cannot be more than 15 characters long, be entirely numeric, or contain the following characters: ` ~ ! @ # $ % ^ & * ( ) = + _ [ ] { } \ | ; : . ' " , < > / ?
$location = 'East US'
$adminUsername = 'Gene'
$vaultName = 'Vault716'

if (-not (Get-Variable -Name cred -Scope global -ErrorAction 'SilentlyContinue'))
{
    $Global:Cred = get-credential $adminUsername
}


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
    location      = $location
    VMName        = $VMName
    adminUsername = $adminUsername
    dnsNamePrefix = "pgsqlrestoretest$Attempt$(get-random -min 1000 -max 9999)"
    vaultName     = $vaultName
}


# Splat the parameters on New-AzureRmResourceGroupDeployment
$SplatParams = @{
    TemplateFile            = $TemplateFile
    ResourceGroupName       = $rgname
    TemplateParameterObject = $MyParams
    adminPassword           = $Global:Cred.Password
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



$Roles = [System.Collections.ArrayList]::new()
$null = $roles.Add('Backup Operator')
# $null = $Roles.Add('_______________')

Get-AzureRmRecoveryServicesVault -name $vaultName -ResourceGroupName $rgname | Set-AzureRmRecoveryServicesVaultContext
$NamedContainer = Get-AzureRmRecoveryServicesBackupContainer -ContainerType AzureVM -Status Registered -FriendlyName $VMName -ResourceGroupName $rgname
$Item = Get-AzureRmRecoveryServicesBackupItem -Container $NamedContainer -WorkloadType AzureVM
Backup-AzureRmRecoveryServicesBackupItem -Item $Item

