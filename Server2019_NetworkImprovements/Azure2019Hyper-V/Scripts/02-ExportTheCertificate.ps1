$subjectName = "EncryptedVirtualNetworks"
$cert = Get-ChildItem cert:\localmachine\my | ? { $_.Subject -eq "CN=$subjectName" } 
[System.io.file]::WriteAllBytes("c:\$subjectName.pfx", $cert.Export("PFX", "secret")) 
Export-Certificate -Type CERT -FilePath "c:\$subjectName.cer" -cert $cert
dir c:\$subjectName.*
