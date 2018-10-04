$NanoDNS = '10.105.246.20'


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
    $NanoServerName = "NanoHypVNode$($index.ToSTring('00'))"
    $Param = @{
        DeploymentType             = 'Guest'
        Edition                    = 'Standard'
        MediaPath                  = 'C:\VMs\Source\'
        TargetPath                 = "C:\VMs\$NanoServerName\$NanoServerName.vhdx"
        EnableRemoteManagementPort = $True
        Clustering                 = $True
        Compute                    = $true
        #GuestDrivers               = $True
        #DomainName                 = 'one.com'
        ComputerName               = $NanoServerName
        AdministratorPassword      = $(ConvertTo-SecureString -string 'Password!101' -AsPlainText -Force)
        MaxSize                    = 20GB
        Verbose                    = $True
        InterfaceNameOrIndex       = 'Ethernet'
        #Ipv4Address = "10.10.10.3$_"
        #Ipv4SubnetMask = '255.255.255.0'
        IpV4Dns                    = $NanoDNS
        #Ipv4Gateway = '10.10.10.1'
    }
    New-NanoServerImage @Param

    # Add the Nano Server to Hyper-V
    $Param = @{
        Name               = $NanoServerName
        MemoryStartupBytes = 2GB
        BootDevice         = 'VHD'
        VHDPath            = "C:\VMs\$NanoServerName`\$NanoServerName.vhdx"
        Path               = "C:\VMs\$NanoServerName"
        Generation         = 2
        Switch             = 'ExternalSwitch'    
    }
    New-VM @Param

    New-VHD -path "C:\VMs\$NanoServerName\$NanoServerName`_D.vhdx" -SizeBytes 50GB -Dynamic
    Add-VMScsiController -VMName $NanoServerName 
    Add-VMHardDiskDrive  -VMName $NanoServerName -ControllerType SCSI -ControllerNumber 1 -ControllerLocation 0 -Path "C:\VMs\$NanoServerName\$NanoServerName`_D.vhdx"

    Start-sleep -s 5

    # Start the Nano Server
    Get-VM -Name $NanoServerName | start-vm 

    # wait for the VM to start.
    $tryCount = 0
    while ((Get-VM -Name $NanoServerName).State -ne 'Running' -and $tryCount -lt 100)
    {
        start-sleep -s 1
        $tryCount++
    }

    # Get the Nano Server's IP Address
    $nanoIP = $null
    $TryCount = 0
    While ($nanoIP -eq $null -And $TryCount -lt 20)
    {
        Write-host -fore yellow "Getting nano IP: Try $TryCount"
        $NanoIP = (get-vm -Name $NanoServerName |? {$_.state -eq 'Running'} | get-vmnetworkadapter).IPAddresses |? {$_ -match "^\d+\.\d+\.\d+\.\d+$"} | select -first 1
        $TryCount++
        Start-Sleep -s 10
    }

    if ($nanoIP -eq $null)
    {
        Throw "Couldn't get Nano Server's IP"
    }
    $NanoIP

    # make sure your system trusts the Nano Server to be able to remote to it.
    $TrustedHosts = @((get-item WSMan:\localhost\Client\TrustedHosts).value.replace(' ', '') -split ',')
    if (-Not $TrustedHosts.Contains($NanoIP))
    {
        Set-Item 'wsman:\localhost\client\trustedhosts' -Value "$NanoIP" -Concatenate
    }

    # Remote the Nano Server
    $Session = new-pssession -ComputerName $nanoIP -Credential ~\administrator

    invoke-command -Session $session -ScriptBlock {
        Set-DnsClientServerAddress -InterfaceAlias 'Ethernet' -ServerAddresses $nanoDNS
        ipconfig /flushdns
        ipconfig /registerdns
    } -ArgumentList $NanoDNS


    #
    #   join the nano server to the domain
    #


    # Remote to the DC
    $TrustedHosts = @((get-item WSMan:\localhost\Client\TrustedHosts).value.replace(' ', '') -split ',')
    if (-Not $TrustedHosts.Contains($NanoDNS))
    {
        Set-Item 'wsman:\localhost\client\trustedhosts' -Value "$NanoDNS" -Concatenate
    }
    $sessiondc = new-pssession -ComputerName $NanoDNS -Credential $(get-credential one\administrator )

    # Make the c:\temp folder where the blob will be stored.
    invoke-command -session $sessiondc -scriptblock {mkdir c:\temp -ErrorAction 'SilentlyContinue'}

    # Create the domain join blob using djoin
    invoke-command -Session $sessiondc -ScriptBlock {
        remove-item "c:\temp\$NanoServerName" -force -ErrorAction 'SilentlyContinue' | Out-Null
        djoin.exe /provision /domain one.com /machine $NanoServerName /SAVEFILE "c:\temp\$NanoServerName" /REUSE
    }

    # copy the blob to the local system
    copy-item "c:\users\administrator\documents\$NanoServerName" -FromSession $sessiondc -Destination c:\temp\ -Force

    # Copy the blog to the nano server.
    invoke-command -Session $Session -ScriptBlock {mkdir c:\temp -ErrorAction 'SilentlyContinue'}
    copy-item "c:\temp\$NanoServerName" -tosession $Session -Destination C:\Temp -Force

    # join the Nano system to the domain using the blog
    invoke-command -session $session -scriptblock {djoin /requestodj /loadfile "c:\temp\$NanoServerName" /windowspath c:\windows /localos}
    invoke-command -session $session -scriptblock {shutdown /r /t 00}

    Start-sleep -Seconds 20

    #
    #    open the firewall
    #

    Invoke-Command -VMName $NanoServerName -ScriptBlock {
        # Configure Firewall
        Set-NetFirewallRule -DisplayName "File and Printer Sharing (Echo Request - ICMPv4-In)" -Profile Any -Enabled True -Direction Inbound -Action Allow
        Set-NetFirewallRule -DisplayName "File and Printer Sharing (Echo Request - ICMPv6-In)" -Profile Any -Enabled True -Direction Inbound -Action Allow
        Set-NetFirewallRule -DisplayName "Failover Clusters (UDP-In)" -Profile Any -Enabled True -Direction Inbound -Action Allow
        Set-NetFirewallRule -DisplayName "Failover Clusters (TCP-In)" -Profile Any -Enabled True -Direction Inbound -Action Allow

        Get-Disk | Where partitionstyle -eq 'RAW' | Initialize-Disk -PartitionStyle GPT -PassThru | New-Partition -AssignDriveLetter -UseMaximumSize | Format-Volume -FileSystem NTFS -NewFileSystemLabel "Hyper-V" -Confirm:$false
    }

#    

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
