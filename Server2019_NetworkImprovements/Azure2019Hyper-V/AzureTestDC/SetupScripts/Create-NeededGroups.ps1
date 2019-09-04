
foreach ($group in @('managers', 'Directors'))
{
    new-adgroup -Name $group -path 'OU=Groups,OU=Corp,OU=Company,DC=one,DC=com' -groupScope Universal -GroupCategory Security
}

foreach ($group in @('Employees'))
{
    new-adgroup -Name $group -path 'OU=DistributionGroups,OU=Corp,OU=Company,DC=one,DC=com' -groupScope Universal -GroupCategory Security
}

