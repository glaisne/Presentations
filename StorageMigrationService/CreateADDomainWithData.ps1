configuration CreateADDomainWithData
{ 
   param 
   ( 
        [Parameter(Mandatory)]
        [String]$DomainName,

        [Parameter(Mandatory)]
        [String]$DomainNetbiosName,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$AdminCreds,

        [Int]$RetryCount=20,
        [Int]$RetryIntervalSec=30
    ) 
    
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName xActiveDirectory
    Import-DscResource -ModuleName xStorage

    [System.Management.Automation.PSCredential ]$DomainCreds = New-Object System.Management.Automation.PSCredential ("$DomainNetbiosName\$($AdminCreds.UserName)", $AdminCreds.Password)

    Node $AllNodes.NodeName
    {
        LocalConfigurationManager
        {
            ActionAfterReboot = 'ContinueConfiguration'
            ConfigurationMode = 'ApplyOnly'
            RebootNodeIfNeeded = $true
            AllowModuleOverWrite = $true
        }

        xWaitforDisk Disk2
        {
            DiskId = '2'
             RetryIntervalSec =$RetryIntervalSec
             RetryCount = $RetryCount
        }

        xDisk ADDataDisk
        {
            DiskId = '2'
            DriveLetter = 'F'
        }

        WindowsFeature ADDSInstall 
        { 
            Ensure = 'Present'
            Name = 'AD-Domain-Services'
        }  

        # Optional GUI tools
        WindowsFeature ADDSTools
        { 
            Ensure = 'Present' 
            Name = 'RSAT-ADDS' 
        }

        xADDomain FirstDS 
        {
            DomainName                    = $DomainName
            DomainNetbiosName             = $DomainNetbiosName
            DomainAdministratorCredential = $DomainCreds
            SafemodeAdministratorPassword = $DomainCreds
            DatabasePath = 'F:\NTDS'
            LogPath = 'F:\NTDS'
            SysvolPath = 'F:\SYSVOL'
            #DependsOn = "[WindowsFeature]ADDSInstall","[xDnsServerAddress]DnsServerAddress","[cDiskNoRestart]ADDataDisk"
            DependsOn = "[WindowsFeature]ADDSInstall","[xDisk]ADDataDisk"
        }

        xWaitForADDomain DscForestWait
        {
            DomainName = $DomainName
            DomainUserCredential = $DomainCreds
            RetryCount = $RetryCount
            RetryIntervalSec = $RetryIntervalSec
            DependsOn = "[xADDomain]FirstDS"
        } 

        xADRecycleBin RecycleBin
        {
           EnterpriseAdministratorCredential = $DomainCreds
           ForestFQDN = $DomainName
           DependsOn = '[xWaitForADDomain]DscForestWait'
        }

        ### OUs ###
        $DomainRoot = "DC=$($DomainName -replace '\.',',DC=')"
        $DependsOn_OU = @()


        ### OUs ###
        $ConfigurationData.NonNodeData.OUs.Foreach({
            if ($_.DependsOn.count -gt 0)
            {
                $DependsOn = $_.DependsOn
            }
            else
            {
                $DependsOn = '[xWaitForADDomain]DscForestWait'
            }
            if($DomainCreds) {
                xADOrganizationalUnit $_.DSCResourceId {
                    Name = $_.Name
                    Description = $_.Description
                    Path = "$($($_.Path -split "dc=")[0])$DomainRoot"
                    Ensure = $_.Ensure
                    ProtectedFromAccidentalDeletion = $_.ProtectedFromAccidentalDeletion
                    Credential = $DomainCreds
                    DependsOn = $DependsOn
                    #DependsOn = $(@('[xWaitForADDomain]DscForestWait') + $_.DependsOn -join ', ').Trim().TrimEnd(',')
                }
            } else {
                xADOrganizationalUnit $_.DSCResourceId {
                    Name = $_.Name
                    Description = $_.Description
                    Path = "$($($_.Path -split "dc=")[0])$DomainRoot"
                    Ensure = $_.Ensure
                    ProtectedFromAccidentalDeletion = $_.ProtectedFromAccidentalDeletion
                    DependsOn = $DependsOn
                    #DependsOn = $(@('[xWaitForADDomain]DscForestWait') + $_.DependsOn -join ', ').Trim().TrimEnd(',')
                }
            }
        })

        $PasswordString = ('abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890'.ToCharArray() | get-random -count 256) -join ''
        $password = ConvertTo-SecureString -String $PasswordString -AsPlainText -Force

        # Users
        $ConfigurationData.NonNodeData.Users.Foreach({
            #$path = ($_.distinguishedName -Split ',dc')[0]
            $path = "$(($($_.distinguishedName -replace "^..\s*=\s*.*?,(\s*..\s*=)", '$1') -Split ',dc')[0]),$DomainRoot"
            $username = if ($_.sAMAccountName -eq $null){''}else{$_.sAMAccountName}
            xADUser "$($_.ObjectGUID)"
            {
                DomainName = $DomainName
                Ensure = 'Present'
                UserName = $_.sAMAccountName
                userPrincipalName = $_.userPrincipalName
                CommonName = $_.CommonName
                givenname = $_.givenname
                Surname = $_.Surname
                Description = $_.Description
                StreetAddress = $_.StreetAddress
                city = $_.city
                state = $_.state
                Postalcode = $_.Postalcode
                country = $_.country
                department = $_.department
                Division = $_.Division
                company = $_.company
                office = $_.office
                JobTitle = $_.Title
                emailaddress = $_.emailaddress
                employeeid = $_.employeeid
                employeenumber = $_.employeenumber
                homedirectory = $_.homedirectory
                officephone = $_.officephone
                manager = $_.manager
                DependsOn = $_.DependsOn
                Path = $path
                Enabled = $true
                Password = New-Object -TypeName PSCredential -ArgumentList 'JustPassword', $password
            }
            # $DependsOn_User += "[xADUser]NewADUser_$($User.UserName)"
        })
    }
}

CreateADDomainWithData -ConfigurationData $ConfigurationData
