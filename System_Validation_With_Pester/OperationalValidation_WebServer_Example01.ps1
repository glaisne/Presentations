Describe "Testing Web Server01" {
    Context "Network" {
        $NetworkCards = Get-CimInstance win32_networkadapterconfiguration -filter "ipenabled = 'True'"
        it "Should be on the network" {
            ($NetworkCards | measure).Count | should BeGreaterThan 0
        }
    }

    Context "Services" {
        it "Server services is running" {
            (Get-Service -name LanmanServer).status | Should Be "Running"
        }
    }
}