# https://docs.microsfot.com/en-us/windows0-server/get-started/update-nano-server


#
# Creating a Nano server
#


# Mount Server 2016 ISO
Mount-DiskImage -ImagePath 'C:\VMs\Source\ISO\Windows Server 2016\14393.0.161119-1705.RS1_REFRESH_SERVER_EVAL_X64FRE_EN-US.ISO' -StorageType ISO
# Copy the NanoServer folder to the local HD
Copy-item -Path d:\NanoServer -Destination c:\vms\source -recurse
# Dismount the ISO
Dismount-DiskImage -ImagePath 'C:\VMs\Source\ISO\Windows Server 2016\14393.0.161119-1705.RS1_REFRESH_SERVER_EVAL_X64FRE_EN-US.ISO'
# Import the module to create the Nano VHDX
import-module C:\vms\Source\NanoServer\NanoServerImageGenerator\NanoServerImageGenerator.psm1
# Create a new Nano VHDX
$NanoServerName = 'NanoIIS'
$Param = @{
    DeploymentType = 'Guest'
    Edition        = 'Standard'
    MediaPath      = 'C:\VMs\Source\'
    TargetPath     = "C:\VMs\$NanoServerName\$NanoServerName.vhdx"
    EnableRemoteManagementPort = $True
    Package                    = 'Microsoft-NanoServer-IIS-Package'
    AdministratorPassword      = $(ConvertTo-SecureString -string 'Password!101' -AsPlainText -Force)
    MaxSize = 20GB
    Verbose = $True
}
New-NanoServerImage @Param

# Add the Nano Server to Hyper-V
$Param = @{
    Name               = $NanoServerName
    MemoryStartupBytes = 2GB
    BootDevice         = 'VHD'
    VHDPath            = "C:\VMs\$NanoServerName\$NanoServerName.vhdx"
    Path               = "C:\VMs\$NanoServerName"
    Generation         = 2
    'Switch'           = 'ExternalSwitch'    
}
New-VM @Param

# Start the Nano Server
Get-VM -Name $NanoServerName | start-vm


#
#    remote Nano
#

# Get the Nano Server's IP Address
$NanoIP = (get-vm -Name $NanoServerName | get-vmnetworkadapter).IPAddresses |? {$_ -match "^\d+\.\d+\.\d+\.\d+$"} | select -first 1
$NanoIP

# make sure your system trusts the Nano Server to be able to remote to it.
dir WSMan:\localhost\client
$TrustedHosts = new-object system.collections.arraylist
$null = $TrustedHosts.AddRange(@((get-item WSMan:\localhost\Client\TrustedHosts).value.replace(' ', '') -split ','))
if (-NOt $TrustedHosts.Contains($NanoIP))
{
    $null = $TrustedHosts.Add($NanoIP)
    set-item wsman:\localhost\client\trustedHosts -value $($TrustedHosts.toArray() -join ',')
}

# Remote the Nano Server
$Session = new-pssession -ComputerName $nanoIP -Credential ~\administrator
Enter-pssession $Session


#
# update Nano
#


# Remote the Nano Server
$Session = new-pssession -ComputerName $nanoIP -Credential ~\administrator
Enter-pssession $Session

# Get the windows version
Get-ItemProperty 'hklm:software\microsoft\windows Nt\currentversion\'

# update Nano
# https://blogs.technet.microsoft.com/nanoserver/2016/01/16/updating-nano-server-using-windows-update-or-windows-server-update-service/
$sess = New-CimInstance -Namespace root/Microsoft/Windows/WindowsUpdate -ClassName MSFT_WUOperationsSession
$scanResults = Invoke-CimMethod -InputObject $sess -MethodName ScanForUpdates -Arguments @{SearchCriteria = "IsInstalled=0"; OnlineScan = $true}
# See what we need:
$scanResults.updates
# update
$Results = Invoke-CimMethod -InputObject $sess -MethodName ApplyApplicableUpdates
# See what was installed
$updateResults = Invoke-CimMethod -InputObject $sess -MethodName ScanForUpdates -Arguments @{SearchCriteria = "IsInstalled=1"; OnlineScan = $true}
$updateResults.updates


#
#    copy files to the Nano
#


# Leave your session (if you're in one)
Exit-PSSession
Copy-Item -Path C:\VMs\Source\WebPages\demo\* -ToSession $Session -Destination C:\inetpub\wwwroot -Recurse
Enter-pssession $Session
cd C:\inetpub\wwwroot
dir

Exit-PSSession
Start "http://$NanoIP"



# Installing a package on Nano server
# Remote managing a Nano Server
#  - Requirements for hyper-v on hyper-v

