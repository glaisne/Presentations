$server = "HyperVHost01-vm"
$subjectname = "EncryptedVirtualNetworks"
# copy c:\$SubjectName.* \\$server\c$
invoke-command -computername $server -ArgumentList $subjectname, 'secret' { 
    param ( 
        [string] $SubjectName, 
        [string] $Secret 
    ) 

    $Secret = 'secret'
    $certFullPath = "c:\$SubjectName.cer"
    # create a representation of the certificate file
    $certificate = new-object System.Security.Cryptography.X509Certificates.X509Certificate2
    $certificate.import($certFullPath)

    # import into the store
    $store = new-object System.Security.Cryptography.X509Certificates.X509Store("Root", "LocalMachine")
    $store.open("MaxAllowed")
    $store.add($certificate)
    $store.close()

    $certFullPath = "c:\$SubjectName.pfx"
    $certificate = new-object System.Security.Cryptography.X509Certificates.X509Certificate2
    $certificate.import($certFullPath, $Secret, "MachineKeySet,PersistKeySet")

    # import into the store
    $store = new-object System.Security.Cryptography.X509Certificates.X509Store("My", "LocalMachine")
    $store.open("MaxAllowed")
    $store.add($certificate)
    $store.close()

    # Important: Remove the certificate files when finished
    remove-item C:\$SubjectName.cer
    remove-item C:\$SubjectName.pfx
}
