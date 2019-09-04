remove-item $env:systemRoot/system32/configuration/pending.mof -force;
get-process *wmi* | stop-process -force;
restart-service winrm -force
