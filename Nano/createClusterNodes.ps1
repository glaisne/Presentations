if (-not $(test-path C:\vms\Source\NanoServer))
{
    # Mount Server 2016 ISO
    Mount-DiskImage -ImagePath 'C:\VMs\Source\ISO\Windows Server 2016\14393.0.161119-1705.RS1_REFRESH_SERVER_EVAL_X64FRE_EN-US.ISO' -StorageType ISO
    # Copy the NanoServer folder to the local HD
    Copy-item -Path d:\NanoServer -Destination c:\vms\source -recurse
    # Dismount the ISO
    Dismount-DiskImage -ImagePath 'C:\VMs\Source\ISO\Windows Server 2016\14393.0.161119-1705.RS1_REFRESH_SERVER_EVAL_X64FRE_EN-US.ISO'
}

# Import the module to create the Nano VHDX
import-module C:\vms\Source\NanoServer\NanoServerImageGenerator\NanoServerImageGenerator.psm1

get-service winrm | start-service

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
    while ((Geet-VM -Name $NanoServerName).State -ne 'Running' -and $tryCount -lt 100) {
        start-sleep -s 1
        $tryCount++
    }

    # Get the Nano Server's IP Address
    $NanoIP = (get-vm -Name $NanoServerName | get-vmnetworkadapter).IPAddresses |? {$_ -match "^\d+\.\d+\.\d+\.\d+$"} | select -first 1

    # make sure your system trusts the Nano Server to be able to remote to it.
    $TrustedHosts = new-object system.collections.arraylist
    $null = $TrustedHosts.AddRange(@((get-item WSMan:\localhost\Client\TrustedHosts).value.replace(' ', '') -split ','))
    if (-NOt $TrustedHosts.Contains($NanoIP))
    {
        $null = $TrustedHosts.Add($NanoIP)
        set-item wsman:\localhost\client\trustedHosts -value $($TrustedHosts.toArray() -join ',') -Confirm:$false -force
    }
}
