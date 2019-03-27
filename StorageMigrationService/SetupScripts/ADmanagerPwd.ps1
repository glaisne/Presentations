$whoami = (&whoami)
if ($whoami.split('\')[1] -ne 'ADManager')
{
    throw 'This scirpt needs to be run by the ADManager user.'
}

if (test-path C:\Scripts\ADManager.pwd)
{
    remove-item C:\Scripts\ADManager.pwd -force
}

'Password!101' | ConvertTo-SecureString -AsPlainText -Force | ConvertFrom-SecureString | Out-File C:\Scripts\ADManager.pwd