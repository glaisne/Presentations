# Replace with thumbprint from your certificate
$thumbprint = "DAE2FE6166DFA652EE64AB22261D682FE6C6690F" 

# Replace with your Network Controller URI
$uri = "___________"   # example: https://nc.contoso.com

Import-module networkcontroller

$credproperties = new-object Microsoft.Windows.NetworkController.CredentialProperties
$credproperties.Type = "X509Certificate"
$credproperties.Value = $thumbprint
New-networkcontrollercredential -connectionuri $uri -resourceid "EncryptedNetworkCertificate" -properties $credproperties -force