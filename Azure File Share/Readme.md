# Benefits of Azure Files
 - You don't have to build and maintian a server.
 - Anything that users SMG or REST can access the file share.
 - redundant
 - Disaster recovery 
    - GRS - if the datacenter goes down, the replica becomes available

# Replication
Storage account repliation
 - Locally-redundant storage (LRS) - All 3 copies in the same zone of a datacenter in the same zone.
 - Zone-redundant storage (ZRS) - 3 copies in the same datacenter but in different zones within the datacenter.
 - Geo-redundant storage (GRS) - 6 copies of the data. 3 in one datacenter, 3 in a geo redundant datacenter
    - ex: 3 in East US, 3 in West US
 - Read-access geo-redundatn stoarage (RA-GRS) - GRS, where the secondary datacenter data is read-only available
    - not applicable to Azure files.

# Encryption
Storage account data is encrypted at rest. the only option to change this is to use your own key and tie it with a Key Vault for storing your data.
 - redundant copies are also encrypted.

 - Encryption in transit is option and requires https via REST API and/or SMB 3.
    - this requires port 445 open
    - test-netconnection -computername <uri> -port 445

# Firewall
 - allow access from Virtual networks
 - Allow access from internet IPs

```powershell
$StorageAccountName = 'sa01ofawesome'
$ResoruceGroup = 'StorageAccountDemo'
$ShareName = 'test01'
$StorageAccount = Get-AZStorageAccount -StorageAccountName $StorageAccountName -ResourceGroupName $ResoruceGroup
$StorageAccountKey = Get-AzStorageAccountKey -name $storageAccountName -ResourceGroupName $ResoruceGroup
$StorageAccountContext = New-AzStorageContext $StorageAccountName -StorageAccountKey $StorageAccountKey[0].value

$Share = get-azStorageShare $ShareName -context $StorageAccountContext

# If there are snapshots
$Share = Get-AzStorageshare $ShareName -context $StorageAccountContext | ? {$_.IsSnapshot -eq $False}

# Create a directory
New-AzStorageDirectory -share $Share -path 'images'

# upload a file
Set-AzStorageFileContent -share $Share -Source 'C:\Users\glais\Pictures\20190507_064533.jpg' -path 'images'

# Download a file from a share
Get-azStorageFileContent -Share $Share -Path 'images\20190507_064533.jpg'

# remove the file
Remove-AzureStorageFile -share $Share -path 'images\20190507_064533.jpg'

# remove the directory
Remove-AzureStorageDirectory -share $Share -path 'images'

##########################################################
# Map a drive
##########################################################

Test-NetConnection -ComputerName "$StorageAccountName`.file.core.windows.net" -Port 445
# Save the password so the drive will persist on reboot
Invoke-Expression -Command "cmdkey /add:$StorageAccountName`.file.core.windows.net /user:Azure\$StorageAccountName /pass:/$($StorageAccountKey[0].value)"
# Mount the drive
New-PSDrive -Name Z -PSProvider FileSystem -Root "\\$StorageAccountName`.file.core.windows.net\$ShareName"

$password = convertto-SecureString -string $StorageAccountKey[0].value -AsPlainText -Force
$Credential = [system.management.automation.pscredential]::new("Azure\$StorageAccountName", $password)
New-PSDrive -Name Z -PSProvider FileSystem -Root "\\$StorageAccountName`.file.core.windows.net\$ShareName" -Credential $Credential -persist

get-smbconnection |fl *

```

# Snapshots
 - through the Azure Portal, you can take snapshots of your data.
 - "Share snapshots are incremental in nature. Only the data that has changed after your most recent share snapshot is saved."
    - https://docs.microsoft.com/en-us/azure/storage/files/storage-snapshots-files
 - Snapshots are read-only.
 - Demo:
    - Take a snapshot through the portal
    - View snapshots through the portal
    - Restore a file through the portal
    - View snapshots through the folder properties on a mapped drive
 - Deleting the File share will delete all the snapshots.

 ## Configure Azure Recovery Services to take regular snapshots
  - The Azure Recovery Services (ARS) needs to be in the same region.
  - Limitations for Azure file share backup: https://docs.microsoft.com/en-us/azure/backup/backup-azure-files#limitations-for-azure-file-share-backup-during-preview
  - Demo:
    - Create Azure Recovery Services Vault
    - Configure to backup File Share
    - Review backup
    - restore file.
    - View snapshots in maped folder properties from the client.

# Azure File Sync
 - Create sync from one Azure Share to one or more Windows file servers.
 - Requires an agent on each windows File server.
    - Windows file servers are registerd with the Storage Sync Service.
 - Storage Sync service needs to be in the same region as the Storage Account.
 - process:
    1) Create file share
    2) Create Storage sync service instance (Azure)
    3) Add the file share to the storage sync service
    4) Install the agent on a file server
    5) Register the file server with the Storage Sync Service
    6) reapeat steps 4 & 5 for each server that will be added.
 - Replication happens via the Azure File Share
    - A file added to a file share is sent to the Azure File Share, then sent to all the other file servers.
    - If a file is edited, the entire file is re-replicated (not just the changes).
    - If a new server is added to an existing Storage Sync Service, the system uses "Rapid Namespace Restore"
        - All of the namespaces will get pulled down (folders, file names...) then it will pull the files down later, in the background. (This feature doesn't work if the share is on the filde servers Sytem Volume.)
 - Demo:
    - Create Azure File Sync
        - Be sure it is in the same region as the storage account.
    - Create a Sync Group.
    - File Server Agent requirements:
        - Disable IE enhanced configuration for the administrators (during registration)
        - AzureRM PowerShell module
    - Download and install the agent on the file server. (https://go.microsoft.com/fwlink/?linkid=858257)
        - Check for hte Storage Sync Agent server which is newly installed.
        - Install the az powershell module if you don't have it already.
    - (Azure) add the server endpoint for the server you just installed the agent on.
        - Set the (Local server) path for the file share.
    - Watch the syncing of files.
        - Add a file on the server and see it sync to Azure.
            - File journaling picks up the new file and uploads it immediately.
        - Add a file on the Azure File Share and see that it doesn't sync right away. 
            - Azure syncs down on a 24 interval.
        


## Coud Tiering
 - Storing "pointers" to real files in the cloud. When a user clicks on the file, it is pulled down from the cloud to the file server.
 - least used files would be in the cloud only.
 - Based on a percentage of free space. Ex: configuring it at 20% means that as the drive gets to 20% free space, the least-used files are moved to Azure, removed from the file server, and a pointer is put in its place.
 - Each file server in a sync group can have its own tiering configuration.
 - Cloud teiring can't be used on the system volume
 -Demo:
```powershell
import-module "c:\program files\azure\storagesyncagent\storagesync.management.servercmdlets...
invoke-storagesynccloudtiering -path <path to file>
```
 - Review the file
 - Open the file
 - review the file again, see that the size on disk is correct.

