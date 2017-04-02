
# get signed drivers
Get-WmiObject win32_pnpsigneddriver |sort deviceclass, devicename |ft deviceclass, devicename, driverversion, driverdate -auto
Get-CimInstance -ClassName win32_pnpsigneddriver |sort deviceclass, devicename |ft deviceclass, devicename, driverversion, driverdate -auto

# Services
(Get-Service -name LanmanServer).status 


# network
Test-NetConnection -computerName localhost -port 3389 -InformationLevel Quiet | should be $True