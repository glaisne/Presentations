# O365 licenses

# looking at users and their licenses

<#
 - User
 |
 |-- Licenses (Collection of Licenses)
   |
   |-- AccountSku
   | |
   | |-- AccountName (tenant ID 'CONTOSO')
   | |
   | |-- SkuPartNumber (License name)
   |
   |-- ServiceStatus (collection of services within a license)
     |
     |-- ProvisioningStatus (is it enabled or disabled)
     |                       * Every option here means enabled with the exception
     |                         of Disabled. You'll see other values like 
     |                         "PendingActivation" consider these to be 'Enabled'.
     |                         Disabled = disabled. everything else = enabled.
     |
     |-- ServicePlan (Information about the service)
       |
       |-- ServiceName (Name of the service)
#>

# Get a user object
$User = get-msoluser -UserPrincipalName gene.laisne@contoso.com


# Look at the user's licenses
$User.Licenses

    # - AccountSku
    # - ServiceStatus

# 2 ways to look at a single licnese
# by AccountSkuId
$User.Licenses |Where-Object {$_.AccountSkuId -like "*ENTERPRISEPACK"}
# by index
$User.Licenses[1]

# Look at AccountSku for a licnese
$User.Licenses[1].AccountSku

    # AccountName = Tenant ID
    # SkuPartNumber = License name

# getting a particular license for a user using AccountSku and SkuPartNumber
$User.Licenses |Where-Object {$_.AccountSku.SkuPartNumber -eq 'ENTERPRISEPACK'}


# Looking at services within a license

# Looking at ServiceStatus
$User.Licenses[1].ServiceStatus
# doing the same thing using Where-Object
($User.Licenses |Where-Object {$_.AccountSku.SkuPartNumber -eq 'ENTERPRISEPACK'}).ServiceStatus
    # Notice the betinning and ending (). Everyting inside the parentheses runs first and returns the 
    # individual license then the '.ServiceStatus' on the end accesses the service status for that license.

    # ServicePlan        - Identifies the service within the license
    # ProvisioningStatus - identifies if it is disabled or not. For this property
    #                      there is a specific rule to know:
    #                      Disabled = disabled
    #                      anything else = Enabled

    # ServicePlan is an identifying object. It has a few additional properties. The one you are most interested
    # in is ServiceName

#
# Adding license to a new user who has no licenses to begin with
#

## To do this, you can either add the entire license to a user with this command:
#----------------------------------------------------------------------------------------------------------------------------
Set-MsolUserLicense -UserPrincipalName gene.laisne@contoso.com -AddLicenses 'ENTERPRISEPACK'
#----------------------------------------------------------------------------------------------------------------------------
## Or, you could add the license with a specific set of services.
## to do this, you need to create a licenseOption object which has (and I HATE this...) all
## the licenses you DON'T want to enable. So, if I want to turn on Exchange only on a 
## E3 license, I have to assign the license and disable everything else. (PITA!)

#----------------------------------------------------------------------------------------------------------------------------
# Create an array of services that does not includ Exchange mailbox.
$DisabledPlans = @('Deskless', 'FLOW_O365_P2', 'POWERAPPS_O365_P2', 'TEAMS1', 'PROJECTWORKMANAGEMENT', 'SWAY', 'INTUNE_O365', 'YAMMER_ENTERPRISE', 'RMS_S_ENTERPRISE', 'OFFICESUBSCRIPTION', 'MCOSTANDARD', 'SHAREPOINTWAC', 'SHAREPOINTENTERPRISE')

# Create the licenseOption object with the list of disabled services.
$LicenseOption = New-MsolLicenseOptions -AccountSkuId 'CONTOSO:ENTERPRISEPACK' -DisabledPlans $DisabledPlans

# set the license.
Set-MsolUserLicense -UserPrincipalName gene.laisne@contoso.com -LicenseOptions $LicenseOption
#----------------------------------------------------------------------------------------------------------------------------

## another option would be to use the Get-MsolAccountSku command, which has info an all the available services for a given license

#----------------------------------------------------------------------------------------------------------------------------
# Create an empty Array
$DisabledPlans = @()

#                             |<------------get services inside the ENTERPRISEPACK (E3) license-------->|
foreach (  $serviceStatus in ( Get-MsolAccountSku |Where-Object {$_.accountskuid -like "*ENTERPRISEPACK"} ).servicestatus  )
{
    if ($serviceStatus.ServicePlan.ServiceName -ne 'EXCHANGE_S_ENTERPRISE')
 {
        # Add the plan to the list of disabled plans
        $DisabledPlans += $serviceStatus.ServicePlan.ServiceName
    }
}
$LicenseOption = New-MsolLicenseOptions -AccountSkuId 'CONTOSO:ENTERPRISEPACK' -DisabledPlans $DisabledPlans

Set-MsolUserLicense -UserPrincipalName gene.laisne@contoso.com -LicenseOptions $LicenseOption
#----------------------------------------------------------------------------------------------------------------------------


#
# Remove a service from a user
#

## to remove a service from a user, you need to determine which services are currently disabled
## and add the service you want to turn off to the list and re-apply the LicenseOptions

#----------------------------------------------------------------------------------------------------------------------------
# create an empty array
$DisabledPlans = @()

# get the user
$user = Get-MsolUser -UserPrincipalName gene.laisne@contoso.com

# get the user's E3 license
$UserLicense = $user.Licenses |Where-Object {$_.AccountSku.SkuPartNumber -eq 'ENTERPRISEPACK'}

# loop through each service within the license
foreach ($ServiceStatus in $UserLicense.ServiceStatus)
{
    # if the service is disabled...
    if ($ServiceStatus.ProvisioningStatus -eq 'Disabled')
    {
        # Add the disabled service name to the list of disabled services.
        $DisabledPlans += $serviceStatus.ServicePlan.ServiceName    
    }
}

# Add the service you want to remove to the list of disabled services
$DisabledPlans += 'SHAREPOINTWAC'

# Set the licenseOption object with the list of disabled services.
$LicenseOption = New-MsolLicenseOptions -AccountSkuId 'CONTOSO:ENTERPRISEPACK' -DisabledPlans $DisabledPlans

# Disable the service on the user.
Set-MsolUserLicense -UserPrincipalName gene.laisne@contoso.com -LicenseOptions $LicenseOption
#----------------------------------------------------------------------------------------------------------------------------


#
# determine if a user has a specific service within a Licnese
#


#----------------------------------------------------------------------------------------------------------------------------
$License = 'ENTERPRISEPACK' # E3
$Service = 'SHAREPOINTWAC'  # OneDrive

$user = Get-MsolUser -UserPrincipalName gene.laisne@contoso.com

if ($user.IsLicensed -eq $false)
{
    write-host "User is not licensed and so does not have the given service ($service)`."
}

if ($user.IsLicensed -eq $true)
{
    # This is a trick to collect all the SkuPartNumbers on all the 
    # AccountSku properties on all the Licenses a user has.
    # in short it creates a collection of them and chackes to see
    # if $License is one of them. if so, it returns $true otherwise
    # it returns $false
    if ($user.Licenses.AccountSku.SkuPartNumber -contains $License)
    {
        # At this point we know the user has the license we want to
        # look at.
        
        # Get the license we want to work with and set it as it's own variable.
        # this way we don't have a long line everytime we want to do something
        # with this license. A shortcut basically.
        $UserLicense = $user.Licenses |Where-Object {$_.AccountSku.SkuPartNumber -eq $license}

        
        # Here, we get the ServiceStatus for the service we want to look at.
        #                 All the service status     Where the service name = 'SHAREPOINTWAC'
        $ServiceStatus = $UserLicense.ServiceStatus |Where-Object {$_.ServicePlan.ServiceName -eq $Service}

        # The $ServiceStatus variable is now the service status for the service we want to look at.
        # we just need to check the ProvisioningStatus
        if ($ServiceStatus.ProvisioningStatus -eq 'Disabled')
        {
            Write-host "The $service service is disabled for this user."
        }
        else
        {
            Write-host "The $service service is Enabled for this user."
        }
    }
    else
    {
        # The user does not have the license we need them to have.
        Write-Host "User does not have the proper licnese ($License) and so, does not have the required service ($service)`."
    }
}
#----------------------------------------------------------------------------------------------------------------------------

<#
Summary
Scripting O365 licenses can be a pain in the arse. Here are some key pieces you want to get to know:
* Getting used to the PowerShell names of services and licenses vs. the "friendly names"
* Getting the one license out of many for a user you'll be working on.
* getting the service within a license for a user you'll be working on.
* understanding that the ServiceStatus tells you the status of the service but that the ServiceStatus.ServicePlan.ServiceName
  identifies the service.
* come to grips with the turn on a service by disabling the others but NOT disabling ones already turned on

These are the things you really need to be aware of. once you understand these things, it's just a matter of having the 
right process and/or the right name for a piece/part.


#>