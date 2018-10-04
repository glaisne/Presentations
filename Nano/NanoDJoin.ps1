# https://docs.microsfot.com/en-us/windows0-server/get-started/update-nano-server

$NanoDNS = '10.105.246.20'

#
# Creating a Nano server
#

# Mount Server 2016 ISO
$imageFilePath = 'C:\VMs\Source\ISO\Windows Server 2016\14393.0.161119-1705.RS1_REFRESH_SERVER_EVAL_X64FRE_EN-US.ISO'
$mount = Mount-DiskImage -ImagePath $imageFilePath -StorageType ISO -passThru

# Identify the new dirve
$newDrive = get-psdrive |? {$_.Used -eq $mount.size}
if (($newDrive | measure).count -gt 1) 
{
    Write-warning "Figure out which drive is the one manually"
}

# Copy the NanoServer folder to the local HD
if (-not (test-path c:\vms\source))
{
    $null = mkdir c:\vms\source
}
Copy-item -Path "$($newdrive.root)NanoServer" -Destination c:\vms\source -recurse -force

# Dismount the ISO
Dismount-DiskImage -ImagePath $imageFilePath

# Import the module to create the Nano VHDX
import-module C:\vms\Source\NanoServer\NanoServerImageGenerator\NanoServerImageGenerator.psm1

# Create a new Nano VHDX
$NanoServerName = 'NanoDJoin'
$Param = @{
    DeploymentType             = 'Guest'
    Edition                    = 'Standard'
    MediaPath                  = 'C:\VMs\Source\'
    TargetPath                 = "C:\VMs\$NanoServerName\$NanoServerName.vhdx"
    EnableRemoteManagementPort = $True
    AdministratorPassword      = $(ConvertTo-SecureString -string 'Password!101' -AsPlainText -Force)
    MaxSize                    = 20GB
    Verbose                    = $True
    # InterfaceNameOrIndex       = 'Ethernet'
    # Ipv4Address                = '10.10.10.12'
    # Ipv4SubnetMask             = '255.255.255.0'
    # IpV4Dns                    = '10.10.10.10'
    # Ipv4Gateway                = '10.10.10.1'
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
    Switch             = 'ExternalSwitch'
    # Switch             = 'InternalSwitch'
}
New-VM @Param

# Start the Nano Server
Get-VM -Name $NanoServerName | start-vm


#
#    remote Nano
#

# Get the Nano Server's IP Address
$nanoIP = $null
$TryCount = 0
While ($nanoIP -eq $null -And $TryCount -lt 10)
{
    $NanoIP = (get-vm -Name $NanoServerName |? {$_.state -eq 'Running'} | get-vmnetworkadapter).IPAddresses |? {$_ -match "^\d+\.\d+\.\d+\.\d+$"} | select -first 1
    $TryCount++
    Start-Sleep -s 10
}
$NanoIP

# make sure your system trusts the Nano Server to be able to remote to it.
# Make sure WinRm is running
if ((get-service winrm).status -ne 'Running') {Start-Service WinRm}

$TrustedHosts = @((get-item WSMan:\localhost\Client\TrustedHosts).value.replace(' ', '') -split ',')
if (-Not $TrustedHosts.Contains($NanoIP))
{
    Set-Item 'wsman:\localhost\client\trustedhosts' -Value "$NanoIP" -Concatenate
}

# Remote the Nano Server
$Session = new-pssession -ComputerName $nanoIP -Credential ~\administrator
Enter-pssession $Session


#
# update Nano
#


# Set Windows Update to use WSUS
# see: https://docs.microsoft.com/en-us/windows-server/get-started/manage-nano-server
# and: https://docs.microsoft.com/en-us/previous-versions/windows/it-pro/windows-server-2008-R2-and-2008/cc708449(v=ws.10)
# if (-not (Test-path 'HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate'))
# {
#     mkdir 'HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate'
# }
# $registryPath = 'HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate'
# $name = 'WUServer'
# $Value = 'http://WSUS01.one.com:8530'
# New-ItemProperty -Path $registryPath -Name $name -Value $value -Force | Out-Null
# $name = 'WUStatusServer'
# New-ItemProperty -Path $registryPath -Name $name -Value $value -Force | Out-Null
# New-ItemProperty -path $registryPath -name TargetGroupEnabled -value 'Nano' -force | out-Null


# Remote the Nano Server
$Session = new-pssession -ComputerName $NanoServerName -Credential ~\administrator
Enter-pssession $Session

# Get the windows version
Get-ItemProperty 'hklm:\software\microsoft\windows Nt\currentversion\'

# update Nano
# https://blogs.technet.microsoft.com/nanoserver/2016/01/16/updating-nano-server-using-windows-update-or-windows-server-update-service/
# $sess = New-CimInstance -Namespace root/Microsoft/Windows/WindowsUpdate -ClassName MSFT_WUOperationsSession
# $scanResults = Invoke-CimMethod -InputObject $sess -MethodName ScanForUpdates -Arguments @{SearchCriteria = "IsInstalled=0"; OnlineScan = $true}
# # See what we need:
# $scanResults.updates
# # update
# $Results = Invoke-CimMethod -InputObject $sess -MethodName ApplyApplicableUpdates
# # See what was installed
# $updateResults = Invoke-CimMethod -InputObject $sess -MethodName ScanForUpdates -Arguments @{SearchCriteria = "IsInstalled=1"; OnlineScan = $true}
# $updateResults.updates


#
#   join the nano server to the domain
#


# Remote to the DC
$TrustedHosts = @((get-item WSMan:\localhost\Client\TrustedHosts).value.replace(' ', '') -split ',')
if (-Not $TrustedHosts.Contains($NanoDNS))
{
    Set-Item 'wsman:\localhost\client\trustedhosts' -Value "$NanoDNS" -Concatenate
}
$sessiondc = new-pssession -ComputerName $NanoDNS -Credential $(get-credential one\administrator)

# Make the c:\temp folder where the blob will be stored.
invoke-command -session $sessiondc -scriptblock {mkdir c:\temp -ErrorAction 'SilentlyContinue'}

# Create the domain join blob using djoin
invoke-command -Session $sessiondc -ScriptBlock {
    djoin.exe /provision /domain one.com /machine $NanoServerName /SAVEFILE "c:\temp\$NanoServerName" /REUSE
} -ArgumentList $NanoServerName

# copy the blob to the local system
copy-item "c:\users\administrator\documents\$NanoServerName" -FromSession $sessiondc -Destination c:\temp\

# Copy the blog to the nano server.
invoke-command -Session $Session -ScriptBlock {mkdir c:\temp -ErrorAction 'SilentlyContinue'}
copy-item "c:\temp\$NanoServerName" -tosession $Session -Destination C:\Temp

# join the Nano system to the domain using the blog
invoke-command -session $session -scriptblock {djoin /requestodj /loadfile "c:\temp\$NanoServerName" /windowspath c:\windows /localos}
invoke-command -session $session -scriptblock {shutdown /r /t 00}




# Installing a package on Nano server
# Remote managing a Nano Server
#  - Requirements for hyper-v on hyper-v

