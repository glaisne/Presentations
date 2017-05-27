Describe "Describe" {
    BeforeEach {
        #Write-host "Describe: BeforeEach"
    }

    BeforeAll {
        #Write-Host "Describe: BeforeAll"
    }

    Context "Context" {
        BeforeEach {
            #Write-host "Context : BeforeEach"
        }

        BeforeAll {
            #Write-Host "Context: BeforeAll"
        }

        it "First Test" {
            "Test" | should BeOfType System.String
        }

        it "Second Test" {
            5      | Should BeOfType int
        }

        it "test" {
            "c:\"    | should exist
        }

        it "bing 1" {
            [net.webrequest]::Create('http://www.bing.com').GetResponse().StatusCode.value__ | should Be 200
        }
        it "bing 2" {
            ([net.webrequest]::Create('http://www.bing.com').GetResponse().StatusCode) -as [int] | should Be 200
        }
        it "bing 3" {
            [net.webrequest]::Create('http://www.bing.com').GetResponse().StatusCode | should Be 'OK'
        }

        # if any one of these fails, the entire test failes.
        # I prefer having each test have its own assertion.
        $ACL = Get-acl C:\temp
        It 'ACL should contain [mydomain\Domain-Admins]' { 
            $ACE = $ACL.Access | where {$_.IdentityReference -eq 'BUILTIN\Administrators'} 
            $ACE | Should Not Be Null 

            $ACE.FileSystemRights  | Should Be 'FullControl' 
            $ACE.AccessControlType | Should Be 'Allow' 
            $ACE.IsInherited       | Should Be $True 
            $ACE.InheritanceFlags  | Should Be 'ContainerInherit, ObjectInherit' 
            $ACE.PropagationFlags  | Should Be 'None' 
        }

        it "Should have Azure Module" {
            get-module Azure -ListAvailable | should not be $null
        }

        it "Azure Module should be version 1.3.2" {
            (get-module Azure -ListAvailable).version | should be '1.3.2'
        }

        it "Azure Module version (major) should be version 1" {
            (get-module Azure -ListAvailable).version.Major | should BeGreaterThan 1
        }
        
        it "Azure Module version (Minor) should be version 3" {
            (get-module Azure -ListAvailable).version.Minor | should BeGreaterThan 3
        }
        
        it "Azure Module version (Build) should be version 2" {
            (get-module Azure -ListAvailable).version.Build | should BeGreaterThan 2
        }

        foreach ($drive in @(Get-WMIObject Win32_LogicalDisk |? {$_.DriveType -eq 3}))
        {
            it "Testing Drive $($drive.name) for available space" {
                $drive.Size / $drive.Freespace * 100 | should BeGreaterThan 10
            }
        }


    }
}