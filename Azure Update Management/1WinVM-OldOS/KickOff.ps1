


#-----------------------------
# Variables
#-----------------------------


$SubscriptionName = 'Visual Studio Enterprise'
$SubscriptionName = 'Pay-As-You-Go'

$Attempt = 'a'
$purpose = '1WinVM Test' # removed the etag

$TemplateFile = "$pwd\azuredeploy.json"
$rgname = "WinVM_OldOS$Attempt" # working on better OUs & Autoshutdown
#$saname = "genesyssa$Attempt"     # Lowercase required
$VMName = 'Server' # Windows computer name cannot be more than 15 characters long, be entirely numeric, or contain the following characters: ` ~ ! @ # $ % ^ & * ( ) = + _ [ ] { } \ | ; : . ' " , < > / ?
$dnsLabelPrefix = "$VMName$(get-random -min 1000 -max 9999)".toLower()
$location = 'East US'
$KeyVaultName = [string]::format("{0}{1}-kv", "$($rgname.replace('.','-').replace('_','-'))-".substring(0, [system.Math]::Min(20, $rgname.length)), $(get-random -min 1000 -max 9999))  # Must match pattern '^[a-zA-Z0-9-]{3,24}$'
$SecretName = "$($rgname.replace('.','').replace('_','-'))`-Secret"
$certificateName = "Azure-$rgname-SSCert" # SSCert = 'Self-Signed Certificate'
$adminUsername = 'Gene'
$cred = $([System.Management.Automation.PSCredential]::new('gene', $(ConvertTo-SecureString -String 'Password!101' -AsPlainText -Force)))
$WindowsOSVersion = '2019-Datacenter'


if ($keyVaultName -notmatch '^[a-zA-Z0-9-]{3,24}$' -or $keyVaultName[0] -notmatch '[a-z]')
{
    Throw "The keyVaultName does not match the pattern '^[a-zA-Z0-9-]{3,24}$' or does not start with a letter"
}

if ($SecretName -notmatch '^[0-9a-zA-Z-]+$')
{
    throw "The secretname '$SecretName' is not valid and does not match the pattern '^[0-9a-zA-Z-]+$'."
}

if ($VMName.length -gt 15)
{
    Throw "VMName ($VMName) is longer than 15 characters."
}

#-----------------------------
# Functions
#-----------------------------


function GetMyIp()
{
    # Get local IP Address
    $url = "http://checkip.dyndns.com"
    $r = Invoke-WebRequest $url
    $r.ParsedHtml.getElementsByTagName("body")[0].innertext.trim().split(' ')[-1]
}


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

try
{
    Select-AzureRmSubscription -SubscriptionName $SubscriptionName -ErrorAction 'Stop'
}
catch 
{
    $err = $_
    If ($_.Exception.Message -like "*Please provide a valid tenant or a valid subscription*")
    {
        Write-Warning "The Subscription Name ($SubscriptionName) may not be valid."
        throw $_
    }
    else
    {
        throw $_
    }
}


# Create the new resource group.
if (-not [string]::isnullorempty($purpose))
{
    New-AzureRmResourceGroup -Name $rgname -Location $Location -Verbose -Tag @{purpose = $purpose}
}
else
{
    New-AzureRmResourceGroup -Name $rgname -Location $Location -Verbose 
}

# Create a Key Vault
$NewVault = New-AzureRmKeyVault -VaultName $KeyVaultName -ResourceGroupName $rgname -Location $location -EnabledForDeployment -EnabledForTemplateDeployment

Write-Warning "[$(Get-Date -format G)] message"

#
#    Create Certificate
#


# Create a self-signed certificate to add to the Key Vault
$certificatefilePath = "$env:temp\$certificateName_$(get-date -f 'MMddyyyyHHmmss')$Attempt.pfx"
$thumbprint = (New-SelfSignedCertificate -DnsName $certificateName -CertStoreLocation Cert:\CurrentUser\My -KeySpec KeyExchange).Thumbprint
$cert = (Get-ChildItem -Path cert:\CurrentUser\My\$thumbprint)
$password = $cred.Password

# $password = Read-Host -Prompt "Please enter the certificate password." -AsSecureString
Export-PfxCertificate -Cert $cert -FilePath $certificatefilePath -Password $password -Force

# Upload the self-signed certificate to the Key Vault
$fileContentBytes = Get-Content $certificatefilePath -Encoding Byte
$fileContentEncoded = [System.Convert]::ToBase64String($fileContentBytes)

$jsonObject = @"
{
  "data": "$filecontentencoded",
  "dataType" :"pfx",
  "password": "$($cred.GetNetworkCredential().Password)"
}
"@

$jsonObjectBytes = [System.Text.Encoding]::UTF8.GetBytes($jsonObject)
$jsonEncoded = [System.Convert]::ToBase64String($jsonObjectBytes)

# Add the secret to the KeyVault
$secret = ConvertTo-SecureString -String $jsonEncoded -AsPlainText -Force
$newSecret = Set-AzureKeyVaultSecret -VaultName $KeyVaultName -Name $SecretName -SecretValue $secret



#
#    Setup Arm Template
#


# Get local public IP Address
$LocalIP = GetMyIp

# Parameters for the template and configuration
$MyParams = @{
    # storageAccount_name = $saname
    location       = $location
    VMName         = $VMName
    CertificateUrl = $newSecret.id
    KeyVaultName   = $KeyVaultName
    NSGSourceIP    = $LocalIP
    adminUsername  = $adminUsername
    dnsLabelPrefix = $dnsLabelPrefix
}

if ($WindowsOSVersion)
{
    $MyParams.Add('WindowsOSVersion', $WindowsOSVersion)
}

if ($MyParams['dnsLabelPrefix'] -cnotmatch '^[a-z][a-z0-9-]{1,61}[a-z0-9]$')
{
    Throw 'dnsLabelPrefix does not match "^[a-z][a-z0-9-]{1,61}[a-z0-9]$"'
}

# Splat the parameters on New-AzureRmResourceGroupDeployment
$SplatParams = @{
    TemplateFile            = $TemplateFile
    ResourceGroupName       = $rgname
    TemplateParameterObject = $MyParams
    Name                    = 'Win2016VM'
    adminPassword           = $Cred.Password
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

