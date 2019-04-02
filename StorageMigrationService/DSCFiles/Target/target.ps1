configuration target
{
    param (
 
        [Parameter(Mandatory=$true)]
        [PSCredential] $DomainCredentials
    )

    Import-DscResource -ModuleName 'PSDscResources'
    Import-DscResource -ModuleName 'xActiveDirectory'
    Import-DscResource -ModuleName 'xNetworking'
    Import-DscResource -ModuleName 'xComputerManagement'
    Import-DscResource -ModuleName 'xPendingReboot'

    $domainName        = 'one.com'

    Node $AllNodes.NodeName
    {

        LocalConfigurationManager
        {
            RebootNodeIfNeeded = $True
        } 
   
        xWaitForADDomain DscForestWait
        {
            DomainName = $domainName
            DomainUserCredential = $DomainCredentials
            RetryCount = 20
            RetryIntervalSec = 60
            RebootRetryCount = 5
        }

        xComputer JoinDomain
        {
            Name       = "Target"
            DomainName = $domainName
            Credential = $DomainCredentials  
        }
    }
}