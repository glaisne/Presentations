param
(
    [string] $StorageRG = 'DSCStorage',
    [string] $StorageAccountName = 'dscstoragen4956259',
    
    [string] $VMName = 'Pull',
    [string] $VMResourceGroup = 'RGDSCPullServer',
    # todo: add validation set here
    [string] $location = 'East US'
)

$DSCScriptFile = "$pwd\CreateADDomainWithData.ps1"
$DSCDataFile = "$pwd\CreateADDomainWithData.psd1"


<#
Note: the IP Address of the system running this command will need to be added to the storage group's
      firewall, otherwise you may receive the following error:

      Publish-AzureRmVMDscConfiguration : The remote server returned an error: (403) Forbidden.
      At line:1 char:1
      + Publish-AzureRmVMDscConfiguration -ConfigurationPath .\CreateADDomain ...
      + ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
          + CategoryInfo          : CloseError: (:) [Publish-AzureRmVMDscConfiguration], StorageException
          + FullyQualifiedErrorId : Microsoft.Azure.Commands.Compute.Extension.DSC.PublishAzureVMDscConfigurationCommand

Note: Use -Force to overwrite the config.
#>
Publish-AzureRmVMDscConfiguration -ConfigurationPath $DSCScriptFile -ResourceGroupName $StorageRG -StorageAccountName $StorageAccountName
<#
Publish-AzureRmVmDscConfiguration uploads the .ps1 and any dsc resourceses specified by the ps1 file in a zip file. the zip file will be 
    uploaded to the storage account under the 'windows-powershell-dsc' container.
#>

$hash = @{'domainname'='one.com';'AdminCreds'=$(Get-Credential gene -Message 'New Domain admin password')}

$params = @{
    ResourceGroupName = $VMResourceGroup
    VMName = $VMName
    ArchiveBlobName = 'CreateADDomainWithData.ps1.zip'
    ArchiveStorageAccountName = $StorageAccountName
    ArchiveContainerName = 'windows-powershell-dsc'
    ConfigurationName = 'CreateADDomainWithData'
    ConfigurationData = $DSCDataFile
    Version = '2.76'
    Location = $location
    AutoUpdate = $true
    ConfigurationArgument = $hash
    ArchiveResourceGroupName = $StorageRG
    force = $true
    DataCollection = 'Enable'
}

Set-AzureRMVMDscExtension @params

# Set-AzureRMVMDscExtension -ResourceGroupName $VMResourceGroup -VMName $VMName -ArchiveBlobName 'CreateADDomainWithData.ps1.zip' -ArchiveStorageAccountName $StorageAccountName -ArchiveContainerName 'windows-powershell-dsc' -ConfigurationName 'CreateADDomainWithData' -ConfigurationData .\CreateADDomainWithData.psd1 -Version "2.76" -Location "East US" -AutoUpdate -ConfigurationArgument $hash -ArchiveResourceGroupName $StorageRG -force

get-azurermvmdscextension -ResourceGroupName $VMResourceGroup -VMName $VMName