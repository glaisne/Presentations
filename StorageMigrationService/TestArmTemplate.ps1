function GetMyIp()
{
    # Get local IP Address
    $url = "http://checkip.dyndns.com"
    $r = Invoke-WebRequest $url
    $r.ParsedHtml.getElementsByTagName("body")[0].innertext.trim().split(' ')[-1]
}


$Attempt = 'j'
$purpose = 'BAWSUG Presentation' # removed the etag

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
