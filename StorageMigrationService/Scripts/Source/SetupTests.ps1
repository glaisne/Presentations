Describe 'DSC' {
    Context 'Installed software/Modules' {
        It 'NuGet' {
            (Get-PackageProvider).name -contains 'NuGet' | Should be $True
            $version = (Get-PackageProvider | Where-Object { $_.name -eq 'nuget' }).version
            $version.major -ge 2 -or ($version.major -eq 2 -and $version.Minor -ge 8) | Should be $True
        }
        It 'Pester' {
            (Get-Module 'Pester' -list).name -contains 'Pester' | Should be $True
            $Version = (Get-Module 'Pester' -list).Version
            $version.major -ge 4 -or ($version.major -eq 4 -and $version.Minor -ge 7) | Should be $True
        }
        It 'PSDscResources' {
            (Get-Module 'PSDscResources' -list).name -contains 'PSDscResources' | Should be $True
            $Version = (Get-Module 'PSDscResources' -list).Version
            $version.major -ge 2 -or ($version.major -eq 2 -and $version.Minor -ge 10) | Should be $True
        }
        It 'xActiveDirectory' {
            (Get-Module 'xActiveDirectory' -list).name -contains 'xActiveDirectory' | Should be $True
            $Version = (Get-Module 'xActiveDirectory' -list).Version
            $version.major -ge 2 -or ($version.major -eq 2 -and $version.Minor -ge 24) | Should be $True
        }
        It 'xStorage' {
            (Get-Module 'xStorage' -list).name -contains 'xStorage' | Should be $True
            $Version = (Get-Module 'xStorage' -list).Version
            $version.major -ge 3 -or ($version.major -eq 3 -and $version.Minor -ge 4) | Should be $True
        }
        It 'xRemoteDesktopAdmin' {
            (Get-Module 'xRemoteDesktopAdmin' -list).name -contains 'xRemoteDesktopAdmin' | Should be $True
            $Version = (Get-Module 'xRemoteDesktopAdmin' -list).Version
            $version.major -ge 1 -or ($version.major -eq 1 -and $version.Minor -ge 1) | Should be $True
        }
        It 'xNetworking' {
            (Get-Module 'xNetworking' -list).name -contains 'xNetworking' | Should be $True
            $Version = (Get-Module 'xNetworking' -list).Version
            $version.major -ge 5 -or ($version.major -eq 5 -and $version.Minor -ge 7) | Should be $True
        }
        It 'xComputerManagement' {
            (Get-Module 'xComputerManagement' -list).name -contains 'xComputerManagement' | Should be $True
            $Version = (Get-Module 'xComputerManagement' -list).Version
            $version.major -ge 4 -or ($version.major -eq 4 -and $version.Minor -ge 1) | Should be $True
        }
        It 'xPendingReboot' {
            (Get-Module 'xPendingReboot' -list).name -contains 'xPendingReboot' | Should be $True
            $Version = (Get-Module 'xPendingReboot' -list).Version
            $version.major -ge 0 -or ($version.major -eq 0 -and $version.Minor -ge 4) | Should be $True
        }
    }
    
    Context 'Demo Setup' {
        It 'There is enough to move' {
            "{0:N2}" -f ((Get-ChildItem C:\users\ -Recurse | Measure-Object -Property Length -Sum -ErrorAction Stop).Sum / 1gb) | should BeGreaterOrEqual 2
        }
    }
}