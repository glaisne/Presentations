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
        Get-PSSession -ea 0 | Where-Object { $_.ComputerName -eq $IPAddress } | Remove-PSSession -ea 0

        Write-Verbose "[$(Get-Date -format G)] $($TryCount.ToString('0000')) Attempting to get PS Session to $IP"
    
        # This was moved from teh script to a function. Bad code... no biscuit!
        # if (-not (get-variable sessionCred -Scope Global -EA 'SilentlyContinue'))
        # {
        #     $Global:sessionCred = get-Credential ~\gene
        # }
    
        try
        {
            $Session = New-PSSession -ConnectionUri "https://$IPAddress`:5986" -credential $Credential -SessionOption (New-PSSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck) -Authentication Negotiate -ErrorAction Stop
            $Connected = $True
        }
        catch
        {
            $err = $_
            Write-Warning "Failed to get sesion: $($Err.Exception.Message)"
            Start-Sleep -s 20
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


$SubscriptionName = 'Visual Studio Enterprise - MPN'
$SubscriptionName = 'Pay-As-You-Go'

$Attempt = 'a'
$purpose = 'BAWSUG Presentaton' # removed the etag

$TemplateFile = "$pwd\azuredeploy.json"
$Location = 'east us'
$rgname = "StorMigSvc$Attempt" # working on better OUs & Autoshutdown
#$saname = "genesyssa$Attempt"     # Lowercase required
#$saType = 'Standard_LRS'
$addnsName = "genesysaddc$Attempt"     # Lowercase required
$sourcednsName = "genesyssource$Attempt"
$targetdnsName = "genesystarget$Attempt"
$adVMName = 'TestDC'
$location = 'East US'
$KeyVaultName = "Vault-$($rgname.replace('.',''))-$(Get-Random -min 1000 -max 9999)"  # Must match pattern '^[a-zA-Z0-9-]{3,24}$'

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
$ExistingKeyVaults = Get-AzureRmKeyVault | Where-Object { $_.Name -match "Vault-$($rgname.replace('.',''))-\d\d\d\d" -and $_.ResourceGroupNAme -eq $rgname }
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
if (-not $(Get-Module azurerm))
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
    New-AzureRmResourceGroup -Name $rgname -Location $Location -Verbose -Tag @{purpose = $purpose }
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
$certificatefilePath = "$env:temp\$certificateName_$(Get-Date -f 'MMddyyyyHHmmss').pfx"
$thumbprint = (New-SelfSignedCertificate -DnsName $certificateName -CertStoreLocation Cert:\CurrentUser\My -KeySpec KeyExchange).Thumbprint
$cert = (Get-ChildItem -Path cert:\CurrentUser\My\$thumbprint)
#$cred = get-credential 'gene'
$cred = [System.Management.Automation.PSCredential]::new('gene', $(ConvertTo-SecureString 'Password!101' -AsPlainText -Force))
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
#    StorageAllowedIP   = $LocalIP
#    StorageAccountName = $saname
#    storageAccountType = $saType
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
#    Name                    = 'StorageAccountName'
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
    Write-Host -fore cyan "$($publicAddress.name) - $($publicAddress.ipAddress) $('-'*100)"
    
    $IP = $PublicAddress.IpAddress
    $DNSFQDN = $PublicAddress.DnsSettings.Fqdn


    # Get a PS Session to the VM
    $Session = $null
    $Session = GetPSSession -IPAddress $IP -credential $cred
    
    Write-Verbose "[$(Get-Date -format G)] Creating DSC folder"
    Invoke-Command { mkdir c:\DSC } -Session $session

    # Install PowerShell 5.1 for the 2008R2 system.
    if ($PublicAddress.Name -eq 'sourcePublicIP')
    {
        Write-Verbose "[$(Get-Date -format G)] Downloading PowerShell 5.1"
        Invoke-Command { 
            $url = 'https://download.microsoft.com/download/6/F/5/6F5FF66C-6775-42B0-86C4-47D41F2DA187/Win7AndW2K8R2-KB3191566-x64.zip';
            $DownloadFile = 'C:\DSC\Win7AndW2K8R2-KB3191566-x64.zip';
            $wc = New-Object System.Net.WebClient;
            Write-Host "Downloading file";
            $wc.DownloadFile($url, $DownloadFile);
        } -session $Session

        Invoke-Command { 
            Write-Host "Extracting archive"
            $DownloadFile = 'C:\DSC\Win7AndW2K8R2-KB3191566-x64.zip';
            $TargetDirectory = 'c:\dsc\Win7AndW2K8R2-KB3191566-x64'
            $shell = New-Object -ComObject shell.application
            $zip = $shell.namespace($downloadFile)
            $null = mkdir $TargetDirectory -ea 0
            foreach ($item in $zip.items())
            {
                $shell.Namespace('c:\dsc\Win7AndW2K8R2-KB3191566-x64').copyhere($item)
            }
        } -Session $Session
        
        Invoke-Command {
            Write-Host "setting execution policy"
            Set-ExecutionPolicy bypass -Force

            Write-Host "Installing PowerShell 5.1"
            # & { C:\DSC\Win7AndW2K8R2-KB3191566-x64\Install-WMF5.1.ps1 -AcceptEULA -AllowRestart }
            #& wusa.exe 'C:\DSC\Win7AndW2K8R2-KB3191566-x64\Win7AndW2K8R2-KB3191566-x64.msu' /log:c:\dsc\Log.txt /quiet /norestart

            # try 2
            mkdir c:\dsc\extract | Out-Null
            Start-Sleep -s 5
            & wusa.exe 'C:\DSC\Win7AndW2K8R2-KB3191566-x64\Win7AndW2K8R2-KB3191566-x64.msu' /extract:c:\dsc\extract /log:c:\dsc\Extractlog.txt

            # 0=Windows6.1-KB2809215-x64.cab
            # 1=Windows6.1-KB2872035-x64.cab
            # 2=Windows6.1-KB2872047-x64.cab
            # 3=Windows6.1-KB3033929-x64.cab
            # 4=Windows6.1-KB3191566-x64.cab

            & Dism.exe /online /add-package /NoRestart /PackagePath:C:\DSC\extract\Windows6.1-KB2809215-x64.cab
            & Dism.exe /online /add-package /NoRestart /PackagePath:C:\DSC\extract\Windows6.1-KB2872035-x64.cab
            & Dism.exe /online /add-package /NoRestart /PackagePath:C:\DSC\extract\Windows6.1-KB2872047-x64.cab
            & Dism.exe /online /add-package /NoRestart /PackagePath:C:\DSC\extract\Windows6.1-KB3033929-x64.cab
            & Dism.exe /online /add-package /NoRestart /PackagePath:C:\DSC\extract\Windows6.1-KB3191566-x64.cab

            Write-Host "Restarting computer"
        } -Session $session

        Write-Verbose "[$(Get-Date -format G)] Restarting Source"
        Restart-AzureRmVM -ResourceGroupName $rgname -Name 'source'

        $Session = $null

        #Start-Sleep -s (60 * 3)

        $ConnectSourceTryCount
        while ($Session.state -ne 'Opened' -and $ConnectSourceTryCount -lt 100)
        {
            $sourcePublicAddress = Get-AzureRmPublicIpAddress -ResourceGroupName $rgname | Where-Object { $_.Name -eq 'sourcePublicIP' }

            $IP = $sourcePublicAddress.IpAddress
            
            $Session = GetPSSession -IPAddress $IP -credential $cred
        } 
    }


    #
    #    Push DSC Configuration to VM
    #


    #
    # Setup the DSC file environment
    Write-Verbose "[$(Get-Date -format G)] Configuring wsman"
    Invoke-Command { Set-Item wsman:\localhost\MaxEnvelopeSizekb -value 50000 } -session $session

    Write-Verbose "[$(Get-Date -format G)] Copying DSC files to server"
    switch ($publicAddress.Name)
    {
        'adPublicIP' 
        {
            $DSCFiles = Get-ChildItem "$pwd\DSCFiles\AD\" -File
            $DSCFiles | ForEach-Object { Copy-Item $_.fullname -Destination c:\DSC\ -ToSession $session }
        }
        'sourcePublicIP'
        {
            $DSCFiles = Get-ChildItem "$pwd\DSCFiles\source\" -File
            $DSCFiles | ForEach-Object { Copy-Item $_.fullname -Destination c:\DSC\ -ToSession $session }
        }
        'targetPublicIP'
        {
            $DSCFiles = Get-ChildItem "$pwd\DSCFiles\target\" -File
            $DSCFiles | ForEach-Object { Copy-Item $_.fullname -Destination c:\DSC\ -ToSession $session }
        }
        Default { }
    }


    # #
    # #    SetupScripts
    # #


    # Invoke-Command { mkdir c:\DSC\Scripts } -Session $session
    # Get-ChildItem .\SetupScripts\*.* | Copy-Item -ToSession $session -Destination c:\DSC\scripts
    # # invoke-command {c:\dsc\Scripts\Install-vscode.ps1 -AdditionalExtensions @('wesbos.theme-cobalt2','alefragnani.bookmarks','aaron-bond.better-comments')} -session $session


    #
    # Scripts
    #


    # invoke-command {mkdir c:\Scripts} -Session $session

    Write-Verbose "[$(Get-Date -format G)] Copying script files to server"
    $LocalZipFilePath = "$pwd\scripts.zip"
    if (Test-Path $LocalZipFilePath -ea 0) { Remove-Item $LocalZipFilePath -Force }
    switch ($publicAddress.Name)
    {
        'adPublicIP' 
        {
            Get-ChildItem "$pwd\scripts\AD\*" | Compress-Archive -DestinationPath $LocalZipFilePath -CompressionLevel optimal
        }
        'sourcePublicIP'
        {
            Get-ChildItem "$pwd\scripts\source\*" | Compress-Archive -DestinationPath $LocalZipFilePath -CompressionLevel optimal
        }
        'targetPublicIP'
        {
            Get-ChildItem "$pwd\scripts\target\*" | Compress-Archive -DestinationPath $LocalZipFilePath -CompressionLevel optimal
        }
        Default { }
    }

    Copy-Item $LocalZipFilePath -ToSession $session -Destination c:\
    Invoke-Command { if (Test-Path c:\scripts.zip -ea 0) { Remove-Item c:\scripts.zip -force } }
    Invoke-Command { Expand-Archive -Path c:\scripts.zip -DestinationPath c:\scripts } -Session $session
    # Invoke-Command { Remove-Item c:\scripts.zip -force }
    Remove-Item $LocalZipFilePath -force
    

    #
    #    Binary files
    #


    Write-Verbose "[$(Get-Date -format G)] Copying binary files to server"
    Invoke-Command { mkdir c:\DSC\bin | Out-Null } -Session $session
    Copy-Item .\bin\* -ToSession $session -Destination c:\DSC\bin -Recurse
    Invoke-Command { Expand-Archive -path 'C:\DSC\bin\AdExplorer.zip' -DestinationPath 'c:\DSC\bin\' -force } -session $session
    # invoke-command {powershell -Command "Expand-Archive -path C:\DSC\bin\AdExplorer.zip -DestinationPath c:\DSC\bin\ -force"} -session $session


    #
    #    Downloads and installs
    #

    # todo: try moving this section to the setup.ps1 script file to be copied to each system


    Write-Verbose "[$(Get-Date -format G)] Install DSC requirements"
    Write-Verbose "[$(Get-Date -format G)]  - Nuget"
    Invoke-Command { $null = Install-PackageProvider -Name 'Nuget' -Force } -session $session
    Invoke-Command { $null = Set-PackageSource -Name psgallery -Trusted } -session $session
    <#
    * Fix pester not installing 
    - The version '4.4.0' of the module 'Pester' being installed is not catalog signed. Ensure that the version '4.4.0' of the module 'Pester' has the catalog file 'Pester.cat' and signed with the same publisher 'CN=Microsoft Root Certificate Authority 2010, O=Microsoft Corporation, L=Redmond, S=Washington, C=US' as the previously-installed module '4.4.0' with version '3.4.0' under the directory 'C:\Program Files\WindowsPowerShell\Modules\Pester\3.4.0'. If you still want to install or update, use -SkipPublisherCheck parameter.
    #>
    Write-Verbose "[$(Get-Date -format G)]  - Pester"
    Invoke-Command { $null = Install-Module -Name Pester -Repository PSGallery -AllowClobber -Force -SkipPublisherCheck } -session $Session
    Write-Verbose "[$(Get-Date -format G)]  - PSDscResources"
    Invoke-Command { $null = Install-Module -Name PSDscResources -Repository PSGallery -AllowClobber -Force } -session $Session
    Write-Verbose "[$(Get-Date -format G)]  - xActiveDirectory"
    Invoke-Command { $null = Install-Module -Name xActiveDirectory -Repository PSGallery -AllowClobber -Force } -session $Session
    Write-Verbose "[$(Get-Date -format G)]  - xStorage"
    Invoke-Command { $null = Install-Module -Name xStorage -Repository PSGallery -AllowClobber -Force } -session $Session
    Write-Verbose "[$(Get-Date -format G)]  - xRemoteDesktopAdmin"
    Invoke-Command { $null = Install-Module -Name xRemoteDesktopAdmin -Repository PSGallery -AllowClobber -Force } -session $Session
    Write-Verbose "[$(Get-Date -format G)]  - xNetworking"
    Invoke-Command { $null = Install-Module -Name xNetworking -Repository PSGallery -AllowClobber -Force } -session $Session
    Write-Verbose "[$(Get-Date -format G)]  - xComputerManagement"
    Invoke-Command { $null = Install-Module -Name xComputerManagement -Repository PSGallery -AllowClobber -Force } -session $Session
    # Write-Verbose "[$(Get-Date -format G)]  - xComputer"
    # Invoke-Command { $null = Install-Module -Name xComputer -Repository PSGallery -AllowClobber -Force } -session $Session
    Write-Verbose "[$(Get-Date -format G)]  - xPendingReboot"
    Invoke-Command { $null = Install-Module -Name xPendingReboot -Repository PSGallery -AllowClobber -Force } -session $Session
    Write-Verbose "[$(Get-Date -format G)]  - DSC"
    switch ($PublicAddress.name)
    {
        'SourcePublicIP'
        {
            Invoke-Command { $null = Dism.exe /online /Enable-Feature /FeatureName:DSC-Service } -session $session
        }
        default
        {
            Invoke-Command { $null = install-windowsfeature DSC-Service } -session $session
        }        
    }
    
    Write-Verbose "[$(Get-Date -format G)]  - chocolatey"
    Invoke-Command { $null = Find-PackageProvider chocolatey | Install-PackageProvider -Force } -session $Session
    Invoke-Command { Set-PackageSource -Name chocolatey -Trusted } -session $session
    Invoke-Command { $null = Find-Package dotnet4.5.2 | Install-Package -Verbose } -session $session
    Invoke-Command { Set-PackageSource -Name chocolatey -Trusted:$false } -session $session
    # invoke-command {find-script install-vscode | save-script -Path c:\DSC\scripts\  } -session $Session
    # invoke-command {unblock-file 'c:\DSC\Scripts\install-vscode.ps1' <# might need one of these: -confirm:$false -force #>} -session $session
    # invoke-command {c:\dsc\Scripts\Install-vscode.ps1 -AdditionalExtensions @('wesbos.theme-cobalt2', 'alefragnani.bookmarks', 'aaron-bond.better-comments')} -session $session

    $Session = $null

    #Start-Sleep -s (60 * 3)

    $ConnectSourceTryCount = 0
    while ($Session.state -ne 'Opened' -and $ConnectSourceTryCount -lt 100)
    {
    #     $sourcePublicAddress = Get-AzureRmPublicIpAddress -ResourceGroupName $rgname | Where-Object { $_.Name -eq 'sourcePublicIP' }

    #     $IP = $sourcePublicAddress.IpAddress
        
         $Session = GetPSSession -IPAddress $IP -credential $cred
    } 


    Write-Verbose "[$(Get-Date -format G)] Deploying DSC configuration to server"
    switch ($publicAddress.Name)
    {
        'adPublicIP' 
        {
            Write-Verbose "[$(Get-Date -format G)] Create DSC MOF files"
            Invoke-Command  -Session $session { . c:\dsc\CreateADDomainWithData.ps1 -DomainName $using:FQDN -DomainNetbiosName $using:NetBiosDomainName -AdminCreds $using:cred } # -ArgumentList $FQDN, $NetBiosDomainName, $cred
            Invoke-Command  -Session $session { createADDomainWithData -ConfigurationData c:\dsc\createADDomainWithData.psd1 -OutputPath 'c:\DSC\CreateADDomainWithData' -DomainName $Using:FQDN -DomainNetbiosName $Using:NetBiosDomainName -AdminCreds $Using:cred } # -ArgumentList $FQDN, $NetBiosDomainName, $cred

            Write-Verbose "[$(Get-Date -format G)] Configuring the LCM"
            Invoke-Command { Set-DscLocalConfigurationManager 'c:\dsc\CreateADDomainWithData\' -Verbose } -session $session
            
            Write-Verbose "[$(Get-Date -format G)] Start DSC Configuration"
            Invoke-Command { Start-DscConfiguration -Path 'c:\dsc\CreateADDomainWithData\' -Wait -Verbose } -session $session

            if ($Session.State -ne 'Opened') { $Session = GetPSSession -IPAddress $IP -credential $cred }

            start-sleep -s 20

            # Run the invoke-Pester tests
            Write-Verbose "[$(Get-Date -format G)] Invoking SchemaFiles pester tests"
            Invoke-Command { Invoke-Pester c:\Scripts\Pester\SchemaFiles.Tests.ps1 } -session $session

            # Extend the schema
            Write-Verbose "[$(Get-Date -format G)] Updating the Schema"
            Invoke-Command { &"c:\Scripts\Schema_Exchange2016-x64\importSchema_new.bat" } -session $session

            Write-Verbose "[$(Get-Date -format G)] Invoking AD pester tests"
            Invoke-Command { Invoke-Pester c:\Scripts\Pester\ADEnvironment.Tests.ps1 } -session $session

            if ($Session.State -ne 'Opened') { $Session = GetPSSession -IPAddress $IP -credential $cred }

        }
        'sourcePublicIP'
        {
            Write-Verbose "[$(Get-Date -format G)] Create DSC MOF files"
            Invoke-Command  -Session $session { . c:\dsc\Source.ps1 -DomainCredentials $( [System.Management.Automation.PSCredential]::new("one\$(($using:cred).username)", $(($using:cred).password) ) ) } 
            Invoke-Command  -Session $session { Source -ConfigurationData c:\dsc\source.psd1 -OutputPath 'c:\DSC\Source' -DomainCredentials $( [System.Management.Automation.PSCredential]::new("one\$(($using:cred).username)", $(($using:cred).password) ) ) } 

            Write-Verbose "[$(Get-Date -format G)] Configuring the LCM"
            Invoke-Command { Set-DscLocalConfigurationManager 'c:\dsc\Source\' -Verbose } -session $session
            
            Write-Verbose "[$(Get-Date -format G)] Start DSC Configuration"
            Invoke-Command { Start-DscConfiguration -Path 'c:\dsc\Source\' -Wait -Verbose } -session $session

            if ($Session.State -ne 'Opened') { $Session = GetPSSession -IPAddress $IP -credential $cred }
            
            Write-Verbose "[$(Get-Date -format G)] Create folder structure to be migrated"
            Invoke-Command { &"c:\scripts\MakeshareTree.ps1" } -session $session
        }
        'targetPublicIP'
        {
            Write-Verbose "[$(Get-Date -format G)] Create DSC MOF files"
            Invoke-Command  -Session $session { . c:\dsc\Target.ps1 -DomainCredentials $( [System.Management.Automation.PSCredential]::new("one\$(($using:cred).username)", $(($using:cred).password) ) ) } 
            Invoke-Command  -Session $session { Target -ConfigurationData c:\dsc\Target.psd1 -OutputPath 'c:\DSC\Target' -DomainCredentials $( [System.Management.Automation.PSCredential]::new("one\$(($using:cred).username)", $(($using:cred).password) ) ) } 

            Write-Verbose "[$(Get-Date -format G)] Configuring the LCM"
            Invoke-Command { Set-DscLocalConfigurationManager 'c:\dsc\Target\' -Verbose } -session $session
            
            Write-Verbose "[$(Get-Date -format G)] Start DSC Configuration"
            Invoke-Command { Start-DscConfiguration -Path 'c:\dsc\Target\' -Wait -Verbose } -session $session

            if ($Session.State -ne 'Opened') { $Session = GetPSSession -IPAddress $IP -credential $cred }
            
            Write-Verbose "[$(Get-Date -format G)] Install prerequsits for migrating files"
            Invoke-Command { &"c:\scripts\StorageMigrationSetup.ps1" } -session $session

            if ($Session.State -ne 'Opened') { $Session = GetPSSession -IPAddress $IP -credential $cred }
        }
        Default { }
    }

}

# $DCIP = $PublicAddresses | Where-Object { $_.name -eq 'adPublicIP' }

# $Session = GetPSSession -IPAddress $DCIP -credential $cred


# # Create the DSC MOF file
# Write-Verbose "[$(Get-Date -format G)] Create DSC MOF files"
# Invoke-Command  -Session $session { . c:\dsc\CreateADDomainWithData.ps1 -DomainName $using:FQDN -DomainNetbiosName $using:NetBiosDomainName -AdminCreds $using:cred } # -ArgumentList $FQDN, $NetBiosDomainName, $cred
# Invoke-Command  -Session $session { createADDomainWithData -ConfigurationData c:\dsc\createADDomainWithData.psd1 -OutputPath 'c:\DSC\CreateADDomainWithData' -DomainName $Using:FQDN -DomainNetbiosName $Using:NetBiosDomainName -AdminCreds $Using:cred } # -ArgumentList $FQDN, $NetBiosDomainName, $cred

# invoke-command -Session $session -ScriptBlock {
#     Write-host -fore yellow "[$(Get-Date -format G)] Dot-Sourcing the DSC file (c:\dsc\CreateADDomainWithData.ps1)"
#     . c:\dsc\CreateADDomainWithData.ps1 -DomainName $FQDN -DomainNetbiosName 'one' -AdminCreds $cred
#     Write-Host -fore Yellow "[$(Get-Date -format G)] Calling the DSC file (c:\dsc\CreateADDomainWithData.ps1)"
#     createADDomainWithData -ConfigurationData c:\dsc\createADDomainWithData.psd1 -OutputPath 'c:\DSC\CreateADDomainWithData' -DomainName $FQDN -DomainNetbiosName 'one' -AdminCreds $cred
# } -ArgumentList $FQDN, $NetBiosDomainName, $cred

# Configure the LCM
# See https://www.jacobbenson.io/index.php/2015/02/21/exploring-the-powershell-dsc-xpendingreboot-resource/
# Write-Verbose "[$(Get-Date -format G)] Configuring the LCM"
# Invoke-Command { Set-DscLocalConfigurationManager 'c:\dsc\CreateADDomainWithData\' -Verbose } -session $session

# Start the DSC configuration
#Write-Verbose "[$(Get-Date -format G)] Start DSC Configuration"
# It seems someimes this fails or runs successfully and doesn't do anything.
# I think it is because the system may not see the F: drive. I'm building this loop
# to try and solve this issue.
# $sw = [System.Diagnostics.Stopwatch]::StartNew()
# $TryCount = 0
# While ($sw.Elapsed.totalSeconds -lt 30 -and $TryCount -le 20)
# {
#     $sw.Reset()
#     $sw.Start()
#Invoke-Command { Start-DscConfiguration -Path 'c:\dsc\CreateADDomainWithData\' -Wait -Verbose } -session $session
#     $sw.stop()
#     Start-Sleep -s 15
#     $TryCount++
# }

# Write-Verbose "[$(Get-Date -format G)] Waiting 5min."
# Start-sleep -s (5 * 60)

# sometimes the DSC takes so long, that we need to get a new session.
# $Session = GetPSSession -IPAddress $IP -credential $cred

# Write-Verbose "[$(Get-Date -format G)] Validate domain"
# Invoke-Command { Get-ADDomain | Format-List * -force } -session $session

# Write-Verbose "[$(Get-Date -format G)] Calling Create-NeededGroups.ps1"
# Invoke-Command { &"C:\DSC\Scripts\create-NeededGroups.ps1" } -session $session

# # Run the invoke-Pester tests
# Write-Verbose "[$(Get-Date -format G)] Invoking SchemaFiles pester tests"
# Invoke-Command { Invoke-Pester c:\Scripts\Pester\SchemaFiles.Tests.ps1 } -session $session

# # Extend the schema
# Write-Verbose "[$(Get-Date -format G)] Updating the Schema"
# Invoke-Command { &"c:\Scripts\Schema_Exchange2016-x64\importSchema_new.bat" } -session $session

# Write-Verbose "[$(Get-Date -format G)] Invoking AD pester tests"
# Invoke-Command { Invoke-Pester c:\Scripts\Pester\ADEnvironment.Tests.ps1 } -session $session

# # RDP either way
# Start-Process -FilePath mstsc.exe -ArgumentList "/v:$DNSFQDN /f"
# # Start-Process -FilePath mstsc.exe -ArgumentList "/v:$IP /f"


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