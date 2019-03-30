# Modified from the original

# Shout out to @brwilkinson for assistance with some of this.


# Install the Azure Resource Manager modules from PowerShell Gallery
# Takes a while to install 28 modules
# Install-Module AzureRM -Force -Verbose
# Install-AzureRM

# Install the Azure Service Management module from PowerShell Gallery
# Install-Module Azure -Force -Verbose

# References:
# https://social.msdn.microsoft.com/Forums/sqlserver/en-US/2a5da0f3-58e0-45b4-ac46-abb2ff352928/winrm-httphttps-differences-between-classicarm-images?forum=WAVirtualMachinesforWindows
# https://docs.microsoft.com/en-us/azure/virtual-machines/windows/key-vault-setup?toc=%2Fazure%2Fvirtual-machines%2Fwindows%2Ftoc.json
# https://docs.microsoft.com/en-us/azure/virtual-machines/windows/winrm?toc=%2Fazure%2Fvirtual-machines%2Fwindows%2Ftoc.json

#todo:  Call the PushDSCExtension as a job
#todo:  Store each unique DSC configuration in a unique container.


#-----------------------------
# Variables
#-----------------------------


$FQDN = 'one.com'
$NetBiosDomainName = 'one'



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
        get-pssession -ea 0 |? {$_.ComputerName -eq $IPAddress} | Remove-PSSession -ea 0

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
# Variables
#-----------------------------


$SubscriptionName = 'Pay-As-You-Go'
$SubscriptionName = 'Visual Studio Enterprise - MPN'

$Attempt = 'g'
$purpose = 'BAWSUG Presentation' # removed the etag

$TemplateFile = "$pwd\azuredeploy.json"
$Location = 'east us'
$rgname = "StorMigSvc$Attempt" # working on better OUs & Autoshutdown
$saname = "genesyssa$Attempt"     # Lowercase required
$saType = 'Standard_LRS'
$addnsName = "genesysaddc$Attempt"     # Lowercase required
$sourcednsName = "genesyssource$Attempt"
$targetdnsName = "genesystarget$Attempt"
$adVMName = 'TestDC'
$location = 'East US'
$KeyVaultName = "Vault-$($rgname.replace('.',''))-$(get-random -min 1000 -max 9999)"  # Must match pattern '^[a-zA-Z0-9-]{3,24}$'

if ($addnsName -notmatch '^[a-z][a-z0-9-]{1,61}[a-z0-9]$')
{
    Throw '$addnsName does not match ^[a-z][a-z0-9-]{1,61}[a-z0-9]$'
}


if ($sourcednsName -notmatch '^[a-z][a-z0-9-]{1,61}[a-z0-9]$')
{
    Throw '$sourcednsName does not match ^[a-z][a-z0-9-]{1,61}[a-z0-9]$'
}

if ($targetdnsName -notmatch '^[a-z][a-z0-9-]{1,61}[a-z0-9]$')
{
    Throw '$targetdnsName does not match ^[a-z][a-z0-9-]{1,61}[a-z0-9]$'
}

if ($KeyVaultName -notmatch '^[a-zA-Z0-9-]{3,24}$')
{
    Throw "the KeyVaultName string variable does not match '^[a-zA-Z0-9-]{3,24}$'"
}

# Delete any already existin KeyVaults
$ExistingKeyVaults = Get-AzureRmKeyVault |? {$_.Name -match "Vault-$($rgname.replace('.',''))-\d\d\d\d" -and $_.ResourceGroupNAme -eq $rgname}
foreach ($ExistingKeyVault in $ExistingKeyVaults)
{
    Remove-AzureRmKeyVault -VaultName $ExistingKeyVault.Name -ResourceGroupName $ExistingKeyVault.ResourceGroupName -Verbose
}

$certificateName = "Azure-$rgname-SSCert" # SSCert = 'Self-Signed Certificate'


#-----------------------------
# Main
#-----------------------------


#
#    Setup Azure Environment
#


# Import AzureRM modules for the given version manifest in the AzureRM module
if (-not $(get-module azurerm))
{
    Import-Module AzureRM -Verbose
}

# Authenticate to your Azure account
# Login-AzureRmAccount

try
{
    Select-AzureRmSubscription -SubscriptionName $SubscriptionName -ErrorAction 'Stop'
}
catch
{
    throw $_
}

# Check that the public dns $addnsName is available
if (Test-AzureRmDnsAvailability -DomainNameLabel $addnsName -Location $Location)
{ 'Available' } else { 'Taken. addnsName must be globally unique.' }

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


#
#    Create Self-Signed certificate for WinRM communications
#


# Create a self-signed certificate to add to the Key Vault
$certificatefilePath = "$env:temp\$certificateName_$(get-date -f 'MMddyyyyHHmmss').pfx"
$thumbprint = (New-SelfSignedCertificate -DnsName $certificateName -CertStoreLocation Cert:\CurrentUser\My -KeySpec KeyExchange).Thumbprint
$cert = (Get-ChildItem -Path cert:\CurrentUser\My\$thumbprint)
#$cred = get-credential 'gene'
$cred = [System.Management.Automation.PSCredential]::new('gene', $(convertto-securestring 'Password!101' -AsPlainText -Force))
#$password = convertto-securestring -string $($cred.GetNetworkCredential().Password) -AsPlainText -Force
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

$secret = ConvertTo-SecureString -String $jsonEncoded -AsPlainText –Force
$SecretName = "$($rgname.replace('.',''))-Secret" # must match '^[0-9a-zA-Z-]+$'
$newSecret = Set-AzureKeyVaultSecret -VaultName $KeyVaultName -Name $SecretName -SecretValue $secret
# $newSecret.id is the url of the secret.


#
#    Setup Arm Template
#


# Get local public IP Address
$LocalIP = GetMyIp

# Parameters for the template and configuration
$MyParams = @{
    location           = $location
    adVMName           = $adVMName
    addnsName          = $addnsName
    sourcednsName      = $sourcednsName
    targetdnsName      = $targetdnsName
    StorageAllowedIP   = $LocalIP
    StorageAccountName = $saname
    storageAccountType = $saType
    CertificateUrl     = $newSecret.id
    KeyVaultName       = $KeyVaultName
    NSGSourceIP        = $LocalIP
    adminPassword      = $Cred.Password
}

# Splat the parameters on New-AzureRmResourceGroupDeployment
$SplatParams = @{
    TemplateFile            = $TemplateFile
    ResourceGroupName       = $rgname
    TemplateParameterObject = $MyParams
    Name                    = 'StorageAccountName'
}

# One prompt for the domain admin password
try
{
    New-AzureRmResourceGroupDeployment @SplatParams -Verbose -DeploymentDebugLogLevel All -ErrorAction Stop
}
catch
{
    throw $_
}

# push the DSC Extension
# Note: Hasn't been working. will be good to come back to this at
#       another point
# $params = @{
#     StorageRG          = $rgname
#     StorageAccountName = $saname
#     VMName             = $adVMName
#     VMResourceGroup    = $rgname
#     location           = $location
#     Force              = $True
#     DSCScriptFile      = "$pwd\CreateADDomainWithData.ps1"
#     DSCDataFile        = "$pwd\CreateADDomainWithData.psd1"
# }
# Write-Verbose "[$(Get-Date -format G)] Pushing the DSC configuration to Azure Storage."
# .\PushDSCExtension.ps1 @params


#
#    Connect to new VM
#


# Find the VM IP and FQDN
$PublicAddresses = Get-AzureRmPublicIpAddress -ResourceGroupName $rgname
$IP = $PublicAddresses.IpAddress
$DNSFQDN = $PublicAddresses.DnsSettings.Fqdn

$VP = $VerbosePreference
$VerbosePreference = 'Continue'

foreach ($PublicAddress in $PublicAddresses)
{
    $IP = $PublicAddress.IpAddress
    $DNSFQDN = $PublicAddress.DnsSettings.Fqdn


    # Get a PS Session to the VM
    $Session = GetPSSession -IPAddress $IP -credential $cred


    #
    #    Push DSC Configuration to VM
    #


    #
    # Setup the DSC file environment
    Write-Verbose "[$(Get-Date -format G)] Setting up DSC files"
    Invoke-Command { mkdir c:\DSC } -Session $session
    Invoke-Command { Get-ChildItem WSMan:\localhost | Format-Table -auto } -session $Session
    Write-Verbose "[$(Get-Date -format G)] Configuring wsman"
    Invoke-Command { Set-Item wsman:\localhost\MaxEnvelopeSizekb -value 50000 } -session $session
    #------------------------------------
    # todo: This needs to be updated for each VM
    Write-Verbose "[$(Get-Date -format G)] Copying DSC files to server"
    Get-ChildItem .\CreateADDomainWithData.ps* | Copy-Item -ToSession $session -Destination c:\DSC\
    #------------------------------------


    #
    #    SetupScripts
    #


    Invoke-Command { mkdir c:\DSC\Scripts } -Session $session
    Get-ChildItem .\SetupScripts\*.* | Copy-Item -ToSession $session -Destination c:\DSC\scripts
    # invoke-command {c:\dsc\Scripts\Install-vscode.ps1 -AdditionalExtensions @('wesbos.theme-cobalt2','alefragnani.bookmarks','aaron-bond.better-comments')} -session $session


    #
    # Scripts
    #


    # invoke-command {mkdir c:\Scripts} -Session $session
    Compress-Archive -Path .\scripts\* -DestinationPath .\scripts.zip -CompressionLevel optimal
    Copy-Item .\scripts.zip -ToSession $session -Destination c:\ # -exclude "get-*File.ps1", "get-function*.ps1" -Recurse
    Invoke-Command { Expand-Archive -Path c:\scripts.zip -DestinationPath c:\scripts } -Session $session
    Invoke-Command { Remove-Item c:\scripts.zip -force }
    Remove-Item .\scripts.zip -force
    # Modules

    #
    #    Binary files
    #


    Invoke-Command { mkdir c:\DSC\bin } -Session $session
    Copy-Item .\bin\* -ToSession $session -Destination c:\DSC\bin -Recurse
    Invoke-Command { Expand-Archive -path 'C:\DSC\bin\AdExplorer.zip' -DestinationPath 'c:\DSC\bin\' -force } -session $session
    # invoke-command {powershell -Command "Expand-Archive -path C:\DSC\bin\AdExplorer.zip -DestinationPath c:\DSC\bin\ -force"} -session $session

    #
    #    Downloads and installs
    #


    Write-Verbose "[$(Get-Date -format G)] Install DSC requirements"
    Write-Verbose "[$(Get-Date -format G)]  - Nuget"
    Invoke-Command { Install-PackageProvider -Name 'Nuget' -Force } -session $session
    Invoke-Command { Set-PackageSource -Name psgallery -Trusted } -session $session
    <#
    * Fix pester not installing 
    - The version '4.4.0' of the module 'Pester' being installed is not catalog signed. Ensure that the version '4.4.0' of the module 'Pester' has the catalog file 'Pester.cat' and signed with the same publisher 'CN=Microsoft Root Certificate Authority 2010, O=Microsoft Corporation, L=Redmond, S=Washington, C=US' as the previously-installed module '4.4.0' with version '3.4.0' under the directory 'C:\Program Files\WindowsPowerShell\Modules\Pester\3.4.0'. If you still want to install or update, use -SkipPublisherCheck parameter.
    #>
    Write-Verbose "[$(Get-Date -format G)]  - Pester"
    Invoke-Command { Install-Module -Name Pester -Repository PSGallery -RequiredVersion '4.4.0' -AllowClobber -Force -SkipPublisherCheck } -session $Session
    Write-Verbose "[$(Get-Date -format G)]  - xActiveDirectory"
    Invoke-Command { Install-Module -Name xActiveDirectory -Repository PSGallery -RequiredVersion '2.19.0.0' -AllowClobber -Force } -session $Session
    Write-Verbose "[$(Get-Date -format G)]  - xStorage"
    Invoke-Command { Install-Module -Name xStorage -Repository PSGallery -RequiredVersion '3.4.0.0' -AllowClobber -Force } -session $Session
    Write-Verbose "[$(Get-Date -format G)]  - xRemoteDesktopAdmin"
    Invoke-Command { Install-Module -Name xRemoteDesktopAdmin -Repository PSGallery -RequiredVersion '1.1.0.0' -AllowClobber -Force } -session $Session
    Write-Verbose "[$(Get-Date -format G)]  - DSC"
    Invoke-Command { install-windowsfeature DSC-Service } -session $session
    Write-Verbose "[$(Get-Date -format G)]  - chocolatey"
    Invoke-Command { Find-PackageProvider chocolatey | Install-PackageProvider -Force } -session $Session
    Invoke-Command { Set-PackageSource -Name chocolatey -Trusted } -session $session
    Invoke-Command { Find-Package dotnet4.5.2 | Install-Package -Verbose } -session $session
    Invoke-Command { Set-PackageSource -Name chocolatey -Trusted:$false } -session $session
    # invoke-command {find-script install-vscode | save-script -Path c:\DSC\scripts\  } -session $Session
    # invoke-command {unblock-file 'c:\DSC\Scripts\install-vscode.ps1' <# might need one of these: -confirm:$false -force #>} -session $session
    # invoke-command {c:\dsc\Scripts\Install-vscode.ps1 -AdditionalExtensions @('wesbos.theme-cobalt2', 'alefragnani.bookmarks', 'aaron-bond.better-comments')} -session $session

}

# Create the DSC MOF file
Write-Verbose "[$(Get-Date -format G)] Create DSC MOF files"
invoke-command  -Session $session {. c:\dsc\CreateADDomainWithData.ps1 -DomainName $using:FQDN -DomainNetbiosName $using:NetBiosDomainName -AdminCreds $using:cred } # -ArgumentList $FQDN, $NetBiosDomainName, $cred
invoke-command  -Session $session {createADDomainWithData -ConfigurationData c:\dsc\createADDomainWithData.psd1 -OutputPath 'c:\DSC\CreateADDomainWithData' -DomainName $Using:FQDN -DomainNetbiosName $Using:NetBiosDomainName -AdminCreds $Using:cred } # -ArgumentList $FQDN, $NetBiosDomainName, $cred

# invoke-command -Session $session -ScriptBlock {
#     Write-host -fore yellow "[$(Get-Date -format G)] Dot-Sourcing the DSC file (c:\dsc\CreateADDomainWithData.ps1)"
#     . c:\dsc\CreateADDomainWithData.ps1 -DomainName $FQDN -DomainNetbiosName 'one' -AdminCreds $cred
#     Write-Host -fore Yellow "[$(Get-Date -format G)] Calling the DSC file (c:\dsc\CreateADDomainWithData.ps1)"
#     createADDomainWithData -ConfigurationData c:\dsc\createADDomainWithData.psd1 -OutputPath 'c:\DSC\CreateADDomainWithData' -DomainName $FQDN -DomainNetbiosName 'one' -AdminCreds $cred
# } -ArgumentList $FQDN, $NetBiosDomainName, $cred

# Configure the LCM
# See https://www.jacobbenson.io/index.php/2015/02/21/exploring-the-powershell-dsc-xpendingreboot-resource/
Write-Verbose "[$(Get-Date -format G)] Configuring the LCM"
invoke-command {Set-DscLocalConfigurationManager 'c:\dsc\CreateADDomainWithData\' -Verbose} -session $session

# Start the DSC configuration
Write-Verbose "[$(Get-Date -format G)] Start DSC Configuration"
# It seems someimes this fails or runs successfully and doesn't do anything.
# I think it is because the system may not see the F: drive. I'm building this loop
# to try and solve this issue.
# $sw = [System.Diagnostics.Stopwatch]::StartNew()
# $TryCount = 0
# While ($sw.Elapsed.totalSeconds -lt 30 -and $TryCount -le 20)
# {
#     $sw.Reset()
#     $sw.Start()
   invoke-command {Start-DscConfiguration -Path 'c:\dsc\CreateADDomainWithData\' -Wait -Verbose} -session $session
#     $sw.stop()
#     Start-Sleep -s 15
#     $TryCount++
# }

# Write-Verbose "[$(Get-Date -format G)] Waiting 5min."
# Start-sleep -s (5 * 60)

# sometimes the DSC takes so long, that we need to get a new session.
$Session = GetPSSession -IPAddress $IP -credential $cred

Write-Verbose "[$(Get-Date -format G)] Validate domain"
invoke-command {Get-ADDomain |fl * -force} -session $session

Write-Verbose "[$(Get-Date -format G)] Calling Create-NeededGroups.ps1"
invoke-command {&"C:\DSC\Scripts\create-NeededGroups.ps1"} -session $session

# Run the invoke-Pester tests
Write-Verbose "[$(Get-Date -format G)] Invoking SchemaFiles pester tests"
invoke-command {Invoke-pester c:\Scripts\Pester\SchemaFiles.Tests.ps1} -session $session

# Extend the schema
Write-Verbose "[$(Get-Date -format G)] Updating the Schema"
invoke-Command {&"c:\Scripts\Schema_Exchange2016-x64\importSchema_new.bat"} -session $session

Write-Verbose "[$(Get-Date -format G)] Invoking AD pester tests"
invoke-command {Invoke-pester c:\Scripts\Pester\ADEnvironment.Tests.ps1} -session $session

# RDP either way
Start-Process -FilePath mstsc.exe -ArgumentList "/v:$DNSFQDN /f"
# Start-Process -FilePath mstsc.exe -ArgumentList "/v:$IP /f"


$VerbosePreference = $VP


<#
History
Version     Who             When            What
1.2         Gene Laisne     ??              - base script using DSC
1.3.0       Gene Laisne     07/12/2018      - abandoning DSC via Set-AzureRMVMDscExtension (for now)
                                            - Working on enabling PS Remoting in the VM to push DSC configuration
1.3.1       Gene Laisne     07/24/2018      - Cleanup changes and re-arranging things for better reading
1.3.2       Gene Laisne     01/15/2019      - Moved to managed disks, removed availability set, worked around broken sessions
                                              Added compess, copy, decompress of the scripts directory.

#>