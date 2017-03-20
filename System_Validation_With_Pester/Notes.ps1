
# get signed drivers
gwmi win32_pnpsigneddriver |sort deviceclass, devicename |ft deviceclass, devicename, driverversion, driverdate -auto