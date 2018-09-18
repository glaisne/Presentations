if (-not $(test-path C:\vms\Source\NanoServer))
{
    # Mount Server 2016 ISO
    Mount-DiskImage -ImagePath 'C:\VMs\Source\ISO\Windows Server 2016\14393.0.161119-1705.RS1_REFRESH_SERVER_EVAL_X64FRE_EN-US.ISO' -StorageType ISO

    # Identify the new dirve
    $newDrive = get-psdrive |? {$_.Used -eq $mount.size}
    if (($newDrive | measure).count -gt 1) 
    {
        Write-warning "Figure out which drive is the one manually"
    }
    
    # Copy the NanoServer folder to the local HD
    Copy-item -Path "$($newdrive.root)NanoServer" -Destination c:\vms\source -recurse
    # Dismount the ISO
    Dismount-DiskImage -ImagePath 'C:\VMs\Source\ISO\Windows Server 2016\14393.0.161119-1705.RS1_REFRESH_SERVER_EVAL_X64FRE_EN-US.ISO'
}

# Import the module to create the Nano VHDX
import-module C:\vms\Source\NanoServer\NanoServerImageGenerator\NanoServerImageGenerator.psm1

if ((get-service winrm).status -ne 'Running'){Start-Service WinRm}

foreach ($index in 1..2)
{
    # Create a new Nano VHDX
    $NanoServerName = "NanoNode$($index.ToSTring('00'))"
    $Param = @{
        DeploymentType             = 'Guest'
        Edition                    = 'Standard'
        MediaPath                  = 'C:\VMs\Source\'
        TargetPath                 = "C:\VMs\$NanoServerName\$NanoServerName.vhdx"
        EnableRemoteManagementPort = $True
        Clustering                 = $True
        AdministratorPassword      = $(ConvertTo-SecureString -string 'Password!101' -AsPlainText -Force)
        MaxSize                    = 20GB
        SetupCompleteCommand       = 'powershell.exe -command {Invoke-CimMethod -InputObject $(New-CimInstance -Namespace root/Microsoft/Windows/WindowsUpdate -ClassName MSFT_WUOperationsSession) -MethodName ApplyApplicableUpdates}'
        Verbose                    = $True
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

    Start-sleep -s 5

    # Start the Nano Server
    Get-VM -Name $NanoServerName | start-vm 

    $tryCount = 0
    while ((Get-VM -Name $NanoServerName).State -ne 'Running' -and $tryCount -lt 100) {
        start-sleep -s 1
        $tryCount++
    }

    # Get the Nano Server's IP Address
    $NanoIP = (get-vm -Name $NanoServerName | get-vmnetworkadapter).IPAddresses |? {$_ -match "^\d+\.\d+\.\d+\.\d+$"} | select -first 1

    # make sure your system trusts the Nano Server to be able to remote to it.
    $TrustedHosts = @((get-item WSMan:\localhost\Client\TrustedHosts).value.replace(' ', '') -split ',')
    if (-Not $TrustedHosts.Contains($NanoIP))
    {
        Set-Item 'wsman:\localhost\client\trustedhosts' -Value "$NanoIP" -Concatenate
    }

    # Remote the Nano Server
    $Session = new-pssession -ComputerName $nanoIP -Credential ~\administrator
    Enter-pssession $Session

    # Get the windows version
    Get-ItemProperty 'hklm:software\microsoft\windows Nt\currentversion\'

    # # update Nano
    # # https://blogs.technet.microsoft.com/nanoserver/2016/01/16/updating-nano-server-using-windows-update-or-windows-server-update-service/
    # $sess = New-CimInstance -Namespace root/Microsoft/Windows/WindowsUpdate -ClassName MSFT_WUOperationsSession
    # $scanResults = Invoke-CimMethod -InputObject $sess -MethodName ScanForUpdates -Arguments @{SearchCriteria = "IsInstalled=0"; OnlineScan = $true}
    # # See what we need:
    # $scanResults.updates
    # # update
    # $Results = Invoke-CimMethod -InputObject $sess -MethodName ApplyApplicableUpdates
}
