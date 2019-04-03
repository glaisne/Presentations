# Firewall rules
get-netfirewallrule -DisplayName 'File and Printer Sharing (SMB-In)' |Enable-NetFirewallRule
get-netfirewallrule -DisplayName 'Netlogon Service (NP-In)' |Enable-NetFirewallRule
get-netfirewallrule -DisplayName 'Windows Management Instrumentation (DCOM-In)' |Enable-NetFirewallRule
Get-NetFirewallRule -DisplayName 'Windows Management Instrumentation (WMI-In)' | Enable-NetFirewallRule
