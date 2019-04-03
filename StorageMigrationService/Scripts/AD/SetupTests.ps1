Describe 'DSC' {
    Context 'Installed software/Modules' {
        IT 'NuGet' {
            (Get-PackageProvider).name -contains 'NuGet' | Should be $True
            $version = (Get-packageprovider | ? {$_.name -eq 'nuget'}).version
            $version.major -ge 2 -or ($version.major -eq 2 -and $version.Minor -ge 8) | should be $True
        }
        IT 'Pester' {
            (Get-module 'Pester' -list).name -contains 'Pester' | should be $True
            $Version = (Get-module 'Pester' -list).Version
            $version.major -ge 4 -or ($version.major -eq 4 -and $version.Minor -ge 7) | should be $True
        }
        IT 'PSDscResources' {
            (Get-module 'PSDscResources' -list).name -contains 'PSDscResources' | should be $True
            $Version = (Get-module 'PSDscResources' -list).Version
            $version.major -ge 2 -or ($version.major -eq 2 -and $version.Minor -ge 10) | should be $True
        }
        IT 'xActiveDirectory' {
            (Get-module 'xActiveDirectory' -list).name -contains 'xActiveDirectory' | should be $True
            $Version = (Get-module 'xActiveDirectory' -list).Version
            $version.major -ge 2 -or ($version.major -eq 2 -and $version.Minor -ge 24) | should be $True
        }
        IT 'xStorage' {
            (Get-module 'xStorage' -list).name -contains 'xStorage' | should be $True
            $Version = (Get-module 'xStorage' -list).Version
            $version.major -ge 3 -or ($version.major -eq 3 -and $version.Minor -ge 4) | should be $True
        }
        IT 'xRemoteDesktopAdmin' {
            (Get-module 'xRemoteDesktopAdmin' -list).name -contains 'xRemoteDesktopAdmin' | should be $True
            $Version = (Get-module 'xRemoteDesktopAdmin' -list).Version
            $version.major -ge 1 -or ($version.major -eq 1 -and $version.Minor -ge 1) | should be $True
        }
        IT 'xNetworking' {
            (Get-module 'xNetworking' -list).name -contains 'xNetworking' | should be $True
            $Version = (Get-module 'xNetworking' -list).Version
            $version.major -ge 5 -or ($version.major -eq 5 -and $version.Minor -ge 7) | should be $True
        }
        IT 'xComputerManagement' {
            (Get-module 'xComputerManagement' -list).name -contains 'xComputerManagement' | should be $True
            $Version = (Get-module 'xComputerManagement' -list).Version
            $version.major -ge 4 -or ($version.major -eq 4 -and $version.Minor -ge 1) | should be $True
        }
        IT 'xPendingReboot' {
            (Get-module 'xPendingReboot' -list).name -contains 'xPendingReboot' | should be $True
            $Version = (Get-module 'xPendingReboot' -list).Version
            $version.major -ge 0 -or ($version.major -eq 0 -and $version.Minor -ge 4) | should be $True
        }
    }
}