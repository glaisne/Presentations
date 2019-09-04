$Attempt = 'c'
$purpose = 'Test something' # removed the etag

$TemplateFile = "$pwd\azuredeploy.json"
$rgname = "Test$Attempt" 
$VMName = 'Server' # Windows computer name cannot be more than 15 characters long, be entirely numeric, or contain the following characters: ` ~ ! @ # $ % ^ & * ( ) = + _ [ ] { } \ | ; : . ' " , < > / ?
$dnsLabelPrefix = "$VMName$(get-random -min 1000 -max 9999)".toLower()
$location = 'East US'
$KeyVaultName = [string]::format("{0}{1}-kv", "$($rgname.replace('.','-').replace('_','-'))-".substring(0, [system.Math]::Min(20, $rgname.length)), $(get-random -min 1000 -max 9999))  # Must match pattern '^[a-zA-Z0-9-]{3,24}$'
$certificateName = "Azure-$rgname-SSCert" # SSCert = 'Self-Signed Certificate'
$adminUsername = 'Gene'
$cred = $([System.Management.Automation.PSCredential]::new('gene', $(ConvertTo-SecureString -String 'Password!101' -AsPlainText -Force)))
$WindowsOSVersion = '2019-Datacenter'
$LogAnalyticName = "$($rgname.replace('.',''))-$(get-random -min 1000 -max 9999)-la"


if ($keyVaultName -notmatch '^[a-zA-Z0-9-]{3,24}$')
{
    Throw "The keyVaultName odes not match the pattern '^[a-zA-Z0-9-]{3,24}$'"
}


# Get local public IP Address
$LocalIP = '10.0.0.1'

# Parameters for the template and configuration
$MyParams = @{
    # storageAccount_name = $saname
    location        = $location
    VMName          = $VMName
    CertificateUrl  = $newSecret.id
    KeyVaultName    = $KeyVaultName
    NSGSourceIP     = $LocalIP
    adminUsername   = $adminUsername
    dnsLabelPrefix  = $dnsLabelPrefix
    LogAnalyticName = $LogAnalyticName
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
