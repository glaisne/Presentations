@{
    AllNodes = @(
        @{
            Nodename = 'localhost'
            PSDscAllowDomainUser = $true
            PSDscAllowPlainTextPassword = $True
        }
    )

    NonNodeData = @{

        OUs = @(
@{
    Description                     = 'Company users and resources'
    DistinguishedName               = 'OU=Company,DC=one,DC=com'
    DSCResourceId                   = '67cb9a39-56fd-4647-b36b-675cbd7d1e85'
    Ensure                          = 'Present'
    Name                            = 'Company'
    Path                            = 'DC=one,DC=com'
    ProtectedFromAccidentalDeletion = $false
},
@{
    Description                     = 'User accounts'
    DistinguishedName               = 'OU=Users,OU=Company,DC=one,DC=com'
    DSCResourceId                   = '7174a3fa-121b-4374-86b5-85fa63e71d05'
    Ensure                          = 'Present'
    Name                            = 'Users'
    Path                            = 'OU=Company,DC=one,DC=com'
    ProtectedFromAccidentalDeletion = $false
},
@{
    Description                     = ''
    DistinguishedName               = 'OU=Contractors,OU=Users,OU=Company,DC=one,DC=com'
    DSCResourceId                   = '483ab9d2-7499-48f0-a2fe-8126b00de0bd'
    Ensure                          = 'Present'
    Name                            = 'Contractors'
    Path                            = 'OU=Users,OU=Company,DC=one,DC=com'
    ProtectedFromAccidentalDeletion = $false
},
@{
    Description                     = ''
    DistinguishedName               = 'OU=Servers,OU=Company,DC=one,DC=com'
    DSCResourceId                   = '09b62675-1128-42d6-b9d1-16af7adbf903'
    Ensure                          = 'Present'
    Name                            = 'Servers'
    Path                            = 'OU=Company,DC=one,DC=com'
    ProtectedFromAccidentalDeletion = $false
},
@{
    Description                     = ''
    DistinguishedName               = 'OU=Groups,OU=Company,DC=one,DC=com'
    DSCResourceId                   = 'ed011dee-dddb-4ccf-9161-fee60d7735ed'
    Ensure                          = 'Present'
    Name                            = 'Groups'
    Path                            = 'OU=Company,DC=one,DC=com'
    ProtectedFromAccidentalDeletion = $false
},
@{
    Description                     = ''
    DistinguishedName               = 'OU=Service Accounts,OU=Users,OU=Company,DC=one,DC=com'
    DSCResourceId                   = 'ef75fcf2-0399-43fa-ad5c-ee99654fe5d4'
    Ensure                          = 'Present'
    Name                            = 'Service Accounts'
    Path                            = 'OU=Users,OU=Company,DC=one,DC=com'
    ProtectedFromAccidentalDeletion = $false
}
)

        Users = @(
@{
    sAMAccountName    = 'glaisne'
    distinguishedName = 'CN=Gene Laisne,OU=Users,OU=Company,DC=one,DC=com'
    ObjectGUID        = '53bf3622-2f78-45d1-a9ac-4bd2e69b3644'
    CommonName        = 'Gene Laisne'
    givenname         = 'Gene'
    initials          = ''
    Surname           = 'Laisne'
    DisplayName       = 'Gene Laisne'
    Description       = ''
    StreetAddress     = '101 dsc way'
    city              = 'Boston'
    state             = 'MA'
    Postalcode        = '02111'
    country           = 'US'
    department        = 'IT'
    Division          = ''
    company           = 'One.com'
    office            = 'Boston'
    title             = 'Sr. Systems Engineer'
    emailaddress      = 'glaisne@one.com'
    employeeid        = '002993'
    employeenumber    = ''
    homedirectory     = ''
    officephone       = ''
    userPrincipalName = 'breed@one.com'
    manager           = ''
    DependsOn         = @('[xADOrganizationalUnit]7174a3fa-121b-4374-86b5-85fa63e71d05')
},
@{
    sAMAccountName    = 'svcSSAdmin'
    distinguishedName = 'CN=svcSSAdmin,OU=Service Accounts,OU=Users,OU=Company,DC=one,DC=com'
    ObjectGUID        = '0cdfc6d9-373c-4e67-964c-6767d98d982e'
    CommonName        = 'svcSSAdmin'
    givenname         = 'svcSSAdmin'
    initials          = ''
    Surname           = ''
    DisplayName       = 'svcSSAdmin'
    Description       = 'Service Account - Source Server Administrator'
    StreetAddress     = ''
    city              = ''
    state             = ''
    Postalcode        = ''
    country           = ''
    department        = ''
    Division          = ''
    company           = 'one'
    office            = ''
    title             = 'ServiceAccount'
    emailaddress      = ''
    employeeid        = ''
    employeeType      = 'ServiceAccount'
    employeenumber    = ''
    homedirectory     = ''
    officephone       = ''
    userPrincipalName = 'svcSSAdmin@one.com'
    manager           = ''
    DependsOn         = @('[xADOrganizationalUnit]ef75fcf2-0399-43fa-ad5c-ee99654fe5d4')
},
@{
    sAMAccountName    = 'svcDSAdmin'
    distinguishedName = 'CN=svcDSAdmin,OU=Service Accounts,OU=Users,OU=Company,DC=one,DC=com'
    ObjectGUID        = '588e631f-22f0-49cd-8da1-1dc805a5220e'
    CommonName        = 'svcDSAdmin'
    givenname         = 'svcDSAdmin'
    initials          = ''
    Surname           = ''
    DisplayName       = 'svcDSAdmin'
    Description       = 'Service Account - Source Server Administrator'
    StreetAddress     = ''
    city              = ''
    state             = ''
    Postalcode        = ''
    country           = ''
    department        = ''
    Division          = ''
    company           = 'one'
    office            = ''
    title             = 'ServiceAccount'
    emailaddress      = ''
    employeeid        = ''
    employeeType      = 'ServiceAccount'
    employeenumber    = ''
    homedirectory     = ''
    officephone       = ''
    userPrincipalName = 'svcDSAdmin@one.com'
    manager           = ''
    DependsOn         = @('[xADOrganizationalUnit]ef75fcf2-0399-43fa-ad5c-ee99654fe5d4')
}
)

    }
}


