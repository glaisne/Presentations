
# get signed drivers
Get-WmiObject win32_pnpsigneddriver |sort deviceclass, devicename |ft deviceclass, devicename, driverversion, driverdate -auto
Get-CimInstance -ClassName win32_pnpsigneddriver |sort deviceclass, devicename |ft deviceclass, devicename, driverversion, driverdate -auto

# Services
(Get-Service -name LanmanServer).status 


# network
Test-NetConnection -computerName localhost -port 3389 -InformationLevel Quiet | should be $True

# Access the Internet
[net.webrequest]::Create('http://www.bing.com').GetResponse().StatusCode.value__ | should Be 200
([net.webrequest]::Create('http://www.bing.com').GetResponse().StatusCode) -as [int] | should Be 200
[net.webrequest]::Create('http://www.bing.com').GetResponse().StatusCode | should Be 'OK'

# Test port
(Test-Port -computer -port 3389).open

# test ACL
$ACL = Get-acl C:\temp
It 'ACL should contain [mydomain\Domain-Admins]' { 
    $ACE = $ACL.Access | where {$_.IdentityReference -eq 'BUILTIN\Administrators'} 
    $ACE | Should Not Be Null 

    $ACE.FileSystemRights  | Should Be 'FullControl' 
    $ACE.AccessControlType | Should Be 'Allow' 
    $ACE.IsInherited       | Should Be $True 
    $ACE.InheritanceFlags  | Should Be 'ContainerInherit, ObjectInherit' 
    $ACE.PropagationFlags  | Should Be 'None' 
}


# Should have a module
get-module activeDirectory -ListAvailable

# Module should be a specific version
(get-module Azure -ListAvailable).version

# Get OS version
(Get-CimInstance Win32_OperatingSystem).version
# or
[environment]::OSVersion.Version

