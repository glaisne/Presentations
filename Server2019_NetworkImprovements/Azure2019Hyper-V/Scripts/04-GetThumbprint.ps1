get-childitem cert://localmachine/my, cert://localmachine/root | ? { $_.Subject -eq "CN=EncryptedVirtualNetworks" }
