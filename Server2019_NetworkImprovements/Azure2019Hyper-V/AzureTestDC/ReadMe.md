# ToDo:
* compress the script folders, upload them, then expand the files.
* Encript the Storage account "at rest" & in transit
  * see https://github.com/Azure/azure-quickstart-templates/blob/c754d7bcf9a4c283c1c9548d04ee6e724573a69d/201-encrypt-running-windows-vm/azuredeploy.json
* Add a startup script
   * see: https://github.com/Azure/azure-quickstart-templates/blob/master/201-vm-custom-script-windows/azuredeploy.json
* Fix the looping test of the DSC status.
  * Contantly trying to get a new session doesn't work.
* Test if we need to have the Web-Server features
  * invoke-command { Remove-WindowsFeature Web-Server -IncludeManagementTools } -session $session  # Not sure if I should do this. :D
* Optimization: Could I kick off the DSC then start the other pieces (ex: install vscode)?
* instead of the .bat file to import the scripts, write a PowerShell script to test for all the needed files first.
  * In one instance some of the early .ldf files didn't get coppied for some reason.
* Add more pester tests
 - Make sure the hradupdate account can create and edit users/groups


# Nice to have:
* Add more root OU copies to increase number of users and manager assignments.
* It would be great if we could configure the VSCode environment before the first run!


# Not needed
* Might need to use xRemoteDesktopAdmin to remove Network Level Authentication (NLM)
  * see: https://github.com/PowerShell/xRemoteDesktopAdmin
  * see: http://www.lazywinadmin.com/2014/04/powershell-getset-network-level.html


# Unproven:
* Added DisplayName in to the DataGenerator
* Add creation of hradupdate user and add the user to the domain admins group.
   * Add creation of the hradupdate password file ('password' | convertto-securestring | convertfrom-securestring | out-file...)
   * This will need to be added as a script file. I get access denied trying to run this in a PSSession.
* Reduce the number of prompts for credentials
* Add DisplayName to the user properties.


# Done:
* Add WinRM to ARM Template
  * Needs a certificate in the Key Vault
  * References:
     * https://social.msdn.microsoft.com/Forums/sqlserver/en-US/2a5da0f3-58e0-45b4-ac46-abb2ff352928/winrm-httphttps-differences-between-classicarm-images?forum=WAVirtualMachinesforWindows
     * https://github.com/Azure/azure-quickstart-templates/tree/master/201-vm-push-certificate-windows
     * https://github.com/Azure/azure-quickstart-templates/tree/master/201-vm-winrm-keyvault-windows
        * Updates:
        * https://azure.microsoft.com/en-us/documentation/articles/virtual-machines-windows-key-vault-setup/
        * https://azure.microsoft.com/en-us/documentation/articles/virtual-machines-windows-winrm/
* Added UPN in
* Added Managers (who are in the given OU structure)
  * Added the dependency for managers (managers get created BEFORE their direct reports)
* Added the installation of .NET 4.5.2 (via chocolatey repository).
  * This is needed for the Exchange schema extension, which is required for the HR script to edit ExtensionAttribute* properties.
* Exchange Schema extension files and batch file added.
   * Kind of tough to add it to the process
* Added manager field back in to the user creation process.
* Pester install with -SkipPublisherCheck
* Changing the Expand archive call from
   * invoke-command {powershell -Command "Expand-Archive -path C:\DSC\bin\AdExplorer.zip -DestinationPath c:\DSC\bin\ -force"} -session $session
  to:
  * invoke-command {Expand-Archive -path C:\DSC\bin\AdExplorer.zip -DestinationPath c:\DSC\bin\ -force} -session $session
    * If this works, consider making this a foreach loop on all *.zip files in the c:\dsc\bin\ directory
* Moving install-VSCode to a download and install rather than a copy from local.
* Added NSG for added network security.
* Added needed groups creation script.
* Added the 'ManualOverrides_temp.csv' file to the hrimport script directory
* Add automated shutdown back in.
* Fix pester not installing 
  - The version '4.4.0' of the module 'Pester' being installed is not catalog signed. Ensure that the version '4.4.0' of the module 'Pester' has the catalog file 'Pester.cat' and signed with the same publisher 'CN=Microsoft Root Certificate Authority 2010, O=Microsoft Corporation, L=Redmond, S=Washington, C=US' as the previously-installed module '4.4.0' with version '3.4.0' under the directory 'C:\Program Files\WindowsPowerShell\Modules\Pester\3.4.0'. If you still want to install or update, use -SkipPublisherCheck parameter.


process:
Run \DataGenerators\Get-ADUsers.ps1 -RootOU 'OU=Company,dc=one,dc=com'
copy the new \DataGenerators\CreateADDomainWithData_MMddYYYYHHmmss.psd1 to \CreateADDomainWithData.psd1
run CallingScript#.ps1
rdp
from cmd (Run as administrator):
 - regsvr32 schmmgmt.dll  (import schema admin )
run C:\Scripts\Schema_Exchange2016-x64\ImportSchema_new.bat
run C:\DSC\Scripts\Create-HRADUpdateUser.ps1
run C:\DSC\Scripts\create-NeededGroups.ps1
create hradupdate pwd file.
  Log in as hradupdate
  'Password!101' | ConvertTo-SecureString -force -AsPlainText | ConvertFrom-SecureString | out-file c:\scripts\hrimport\hradupdate.pwd
INI file changes
 - Make debug=1 in the .ini file.
 - Make sure the test (HR Data) file is the right name.

Run the script!