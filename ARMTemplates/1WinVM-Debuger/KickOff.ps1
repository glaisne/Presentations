[CmdletBinding()]
param (
        
)

#-----------------------------
# Variables
#-----------------------------


$SubscriptionName = 'Visual Studio Enterprise'
$SubscriptionName = 'Pay-As-You-Go'

$Attempt = 'd'
$purpose = '1WinVM Test' # removed the etag

$TemplateFile = "$pwd\azuredeploy.json"
$rgname = "WinVM_Test$Attempt" # working on better OUs & Autoshutdown
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

function GetPSSession
{
    param (
        [parameter(mandatory)]
        [string] $IPAddress,

        # Specify credentials for this CmdLet
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential = [System.Management.Automation.PSCredential]::Empty
    )
    $trycount = 0
    $Connected = $false
    While ($Trycount -lt 20 -and $connected -eq $False)
    {
        # Destroy the old!
        get-pssession -ea 0 | ? { $_.ComputerName -eq $IPAddress } | Remove-PSSession -ea 0

        Write-Verbose "[$(Get-Date -format G)] $($TryCount.ToString('0000')) Attempting to get PS Session to $IP"
    
        # This was moved from teh script to a function. Bad code... no biscuit!
        # if (-not (get-variable sessionCred -Scope Global -EA 'SilentlyContinue'))
        # {
        #     $Global:sessionCred = get-Credential ~\gene
        # }
    
        try
        {
            $Session = new-pssession -ConnectionUri "https://$IPAddress`:5986" -credential $Credential -SessionOption (New-PSSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck) -Authentication Negotiate -ErrorAction Stop
            $Connected = $True
        }
        catch
        {
            $err = $_
            Write-warning "Failed to get sesion: $($Err.Exception.Message)"
            Start-sleep -s 20
        }
        $trycount++
    }

    $Session
}

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
    New-AzureRmResourceGroup -Name $rgname -Location $Location -Verbose -Tag @{purpose = $purpose }
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

$Global:results | fl * -force

# One prompt for the domain admin password
try
{
    New-AzureRmResourceGroupDeployment @SplatParams -Verbose -DeploymentDebugLogLevel All -ErrorAction Stop
}
catch
{
    throw $_
}



#
#    Connect to new VM
#


# Find the VM IP and FQDN
$PublicAddress = (Get-AzureRmPublicIpAddress -ResourceGroupName $rgname)[0]
$IP = $PublicAddress.IpAddress
$DNSFQDN = $PublicAddress.DnsSettings.Fqdn

$VP = $VerbosePreference
$VerbosePreference = 'Continue'

# Get a PS Session to the VM
$Session = GetPSSession -IPAddress $IP -credential $cred

Write-Verbose "[$(Get-Date -format G)] Setup debug symbols"
invoke-command { $env:_NT_SYMBOL_PATH = "srv*c:\symbols*http://msdl.microsoft.com/download/symbols" } -Session $session

Write-Verbose "[$(Get-Date -format G)]  - Nuget"
invoke-command { install-packageProvider -Name 'Nuget' -Force } -session $session
invoke-command { set-packagesource -Name psgallery -Trusted } -session $session

Write-Verbose "[$(Get-Date -format G)]  - chocolatey"
invoke-command { find-packageprovider chocolatey | install-packageprovider -Force } -session $Session
invoke-command { set-packagesource -Name chocolatey -Trusted } -session $session

Write-Verbose "[$(Get-Date -format G)]  - dotnet4.5.2"
invoke-command { find-package dotnet4.5.2 | install-package -Verbose } -session $session

Write-Verbose "[$(Get-Date -format G)] Install windows-sdk-10-version-1903-windbg"
invoke-command { find-package 'windows-sdk-10-version-1903-windbg' | install-package -Force }
