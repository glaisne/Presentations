# toDo: Add dependsOn for OU the user is in.

param(
    [string[]] $RootOU
)

Import-module adtools

#-----------------------------
# Functions
#-----------------------------


function Invoke-Template
{
    param(     
        [string]$TemplatePath = "$pwd",        
        [ScriptBlock]$ScriptBlock
    )

    function Get-Template
    {
        param($TemplateFileName)

        $content = [IO.File]::ReadAllText( (dir (Join-Path $TemplatePath $TemplateFileName)).FullName )
        Invoke-Expression "@`"`r`n$content`r`n`"@"
    }

    & $ScriptBlock
}




#-----------------------------
# Variables
#-----------------------------

# psd1 file
$psd1FileTemplate = @'
@{
    AllNodes = @(
        @{
            Nodename = 'localhost'
            PSDscAllowDomainUser = `$true
            PSDscAllowPlainTextPassword = `$True
        }
    )

    NonNodeData = @{

        $OUs

        $Users

    }
}

'@


$AllOUs = [System.Collections.ArrayList]::new()

# User stuff
$UserProperties = @('sAMAccountName', 'userPrincipalName','distinguishedName', 'ObjectGUID', 'cn', 'givenname', 'initials', 'Surname', 'DisplayName', 'Description', 'StreetAddress','city','state','Postalcode','country','department','Division','company','office','title','emailaddress','employeeid','employeenumber','homedirectory','officephone','manager')

$UserCollection = [System.Collections.ArrayList]::new()

$UserHashtableTemplate = @'
    sAMAccountName    = '$sAMAccountName'
    distinguishedName = '$distinguishedName'
    ObjectGUID        = '$ObjectGUID'
    CommonName        = '$CommonName'
    givenname         = '$givenname'
    initials          = '$initials'
    Surname           = '$Surname'
    DisplayName       = '$DisplayName'
    Description       = '$Description'
    StreetAddress     = '$StreetAddress'
    city              = '$city'
    state             = '$state'
    Postalcode        = '$Postalcode'
    country           = '$country'
    department        = '$department'
    Division          = '$Division'
    company           = '$company'
    office            = '$office'
    title             = '$title'
    emailaddress      = '$emailaddress'
    employeeid        = '$employeeid'
    employeenumber    = '$employeenumber'
    homedirectory     = '$homedirectory'
    officephone       = '$officephone'
    userPrincipalName = '$userPrincipalName'
    manager           = '$manager'
    DependsOn         = $DependsOn
'@


# OU Stuff
$OUProperties = @('DistinguishedName','ObjectGUID','Description','Name')

$OUCollection = [System.Collections.ArrayList]::new()

$OUHashtableTemplate = @'
    Description                     = '$Description'
    DistinguishedName               = '$DistinguishedName'
    DSCResourceId                   = '$DSCResourceId'
    Ensure                          = 'Present'
    Name                            = '$Name'
    Path                            = '$Path'
    ProtectedFromAccidentalDeletion = `$false
'@

#-----------------------------
# Main
#-----------------------------

# Create the template file
$psd1FileTemplate      | Out-File "$($env:TEMP)\PSD1FileTemplate.txt" -Force
$UserHashtableTemplate | Out-File "$($env:TEMP)\Usertemplate.txt" -Force
$OUHashtableTemplate   | out-File "$($env:TEMP)\OUtemplate.txt" -Force

$AllUsersHashTable = @{}
foreach ($ou in $RootOU)
{
    # Collect all the OUs under the given RootOU(s)
    $null = $AllOUs.AddRange(@($(Get-ADOrganizationalUnit -filter * -searchbase $ou -properties $OUProperties)))

    # Collect all the users under the give OU(s)
    $users = get-aduser -filter * -searchbase $ou
    foreach ($User in $Users)
    {
        # Get users keyed off of DN for eventual manager dependencies
        $null = $AllUsersHashTable.Add($user.DistinguishedName, $user)
    }
}

# Get all the users under the OU and create a hash table
# with the distinguishedName as the key

foreach ($OU in $AllOUs)
{
    $ParentPath = Split-ADDNPath $OU.DistinguishedName

    if ($ParentPath -like "DC=*")
    {
        $DependsOn = '[xWaitForADDomain]DscForestWait'
    }
    else
    {
        $DependsOn = ($AllOUs |? {$_.DistinguishedName -eq $ParentPath}).objectguid.tostring()
    }

    $null = $OUCollection.Add($(Invoke-Template "$($env:TEMP)" {
                $Description = [System.Management.Automation.Language.CodeGeneration]::EscapeSingleQuotedStringContent($OU.Description)
                $DistinguishedName = [System.Management.Automation.Language.CodeGeneration]::EscapeSingleQuotedStringContent($OU.DistinguishedName)
                $DSCResourceId = $OU.ObjectGuid
                $Name = [System.Management.Automation.Language.CodeGeneration]::EscapeSingleQuotedStringContent($OU.Name)
                $DependsOn = [System.Management.Automation.Language.CodeGeneration]::EscapeSingleQuotedStringContent($DependsOn)
                $path = [System.Management.Automation.Language.CodeGeneration]::EscapeSingleQuotedStringContent($ParentPath)
                Get-Template -TemplateFileName "OUtemplate.txt"
            }))

    $users = get-aduser -filter * -searchbase $OU.distinguishedName -SearchScope OneLevel -properties $UserProperties | select $UserProperties

    foreach ($user in $users)
    {
        $DependsOn = [System.Collections.ArrayList]::new()
        $parentOU = Split-ADDNPath $user.DistinguishedName

        # Add the parent OU to the DependsOn array
        $null = $DependsOn.Add("[xADOrganizationalUnit]$(($AllOUs |? {$_.DistinguishedName -eq $parentOU}).objectguid.tostring())")

        # if the manager is in this OU 'branch' add the manager
        # not only as a user property, but as a 'DependsOn' value
        if ($user.manager -in $AllUsersHashTable.keys)
        {
            # Add the manger to the DependsOn Array
            $null = $DependsOn.Add("[xADUser]$($AllUsersHashTable[$user.manager].ObjectGUID)")
        }
        else
        {
            # If we don't have the manager, remove it from the user properties
            # not having the manager exist will cause issues.
            $user.Manager = [string]::Empty
        }

        # Format the DependsOn value as an array
        $DependsOn = "@('{0}')" -f $(($DependsOn | % {[System.Management.Automation.Language.CodeGeneration]::EscapeSingleQuotedStringContent($_)}) -join ''',''')
    
        $null = $userCollection.Add($(Invoke-Template "$($env:TEMP)" {
                    $sAMAccountName = [System.Management.Automation.Language.CodeGeneration]::EscapeSingleQuotedStringContent($user.sAMAccountName)
                    $userPrincipalName = [System.Management.Automation.Language.CodeGeneration]::EscapeSingleQuotedStringContent($user.userPrincipalName)
                    $distinguishedName = [System.Management.Automation.Language.CodeGeneration]::EscapeSingleQuotedStringContent($user.distinguishedName)
                    $ObjectGUID = $user.ObjectGUID
                    $CommonName = [System.Management.Automation.Language.CodeGeneration]::EscapeSingleQuotedStringContent($user.cn)
                    $givenname = [System.Management.Automation.Language.CodeGeneration]::EscapeSingleQuotedStringContent($user.givenname)
                    $initials = [System.Management.Automation.Language.CodeGeneration]::EscapeSingleQuotedStringContent($user.initials)
                    $Surname = [System.Management.Automation.Language.CodeGeneration]::EscapeSingleQuotedStringContent($user.Surname)
                    $DisplayName = [System.Management.Automation.Language.CodeGeneration]::EscapeSingleQuotedStringContent($user.DisplayName)
                    $Description = [System.Management.Automation.Language.CodeGeneration]::EscapeSingleQuotedStringContent($user.Description)
                    $StreetAddress = [System.Management.Automation.Language.CodeGeneration]::EscapeSingleQuotedStringContent($user.StreetAddress)
                    $city = [System.Management.Automation.Language.CodeGeneration]::EscapeSingleQuotedStringContent($user.city)
                    $state = [System.Management.Automation.Language.CodeGeneration]::EscapeSingleQuotedStringContent($user.state)
                    $Postalcode = [System.Management.Automation.Language.CodeGeneration]::EscapeSingleQuotedStringContent($user.Postalcode)
                    $country = [System.Management.Automation.Language.CodeGeneration]::EscapeSingleQuotedStringContent($user.country)
                    $department = [System.Management.Automation.Language.CodeGeneration]::EscapeSingleQuotedStringContent($user.department)
                    $Division = [System.Management.Automation.Language.CodeGeneration]::EscapeSingleQuotedStringContent($user.Division)
                    $company = [System.Management.Automation.Language.CodeGeneration]::EscapeSingleQuotedStringContent($user.company)
                    $office = [System.Management.Automation.Language.CodeGeneration]::EscapeSingleQuotedStringContent($user.office)
                    $title = [System.Management.Automation.Language.CodeGeneration]::EscapeSingleQuotedStringContent($user.title)
                    $emailaddress = [System.Management.Automation.Language.CodeGeneration]::EscapeSingleQuotedStringContent($user.emailaddress)
                    $employeeid = [System.Management.Automation.Language.CodeGeneration]::EscapeSingleQuotedStringContent($user.employeeid)
                    $employeenumber = [System.Management.Automation.Language.CodeGeneration]::EscapeSingleQuotedStringContent($user.employeenumber)
                    $homedirectory = [System.Management.Automation.Language.CodeGeneration]::EscapeSingleQuotedStringContent($user.homedirectory)
                    $officephone = [System.Management.Automation.Language.CodeGeneration]::EscapeSingleQuotedStringContent($user.officephone)
                    $manager = [System.Management.Automation.Language.CodeGeneration]::EscapeSingleQuotedStringContent($user.manager)
                    $DependsOn = $DependsOn
    
                    Get-Template -TemplateFileName "Usertemplate.txt"
                }))
    }

}


#write-host $("Users = @(`n" + $(($userCollection | % {"@{`n$_}"}) -join ",`n") + "`n)")
#write-host $("OUs = @(`n" + $(($OUCollection | % {"@{`n$_}"}) -join ",`n") + "`n)")

Invoke-Template "$($env:TEMP)" {
    $OUs = "OUs = @(`r`n" + $(($OUCollection | % {"@{`r`n$_}"}) -join ",`r`n") + "`r`n)"
    $Users = "Users = @(`r`n" + $(($UserCollection | % {"@{`r`n$_}"}) -join ",`r`n") + "`r`n)"

    Get-Template -TemplateFileName "PSD1FileTemplate.txt"
} | out-file "$pwd\CreateADDomainWithData_$(get-date -f 'MMddyyyyHHmmss')`.psd1"
