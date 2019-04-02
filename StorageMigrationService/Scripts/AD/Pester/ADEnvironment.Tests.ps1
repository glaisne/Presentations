
Describe 'Test AD Environment Tests' {

    Context 'AD' {
        IT 'Extension Attribute 7 exists' {
            $schema = [directoryservices.activedirectory.activedirectoryschema]::getcurrentschema()
            $EA7 = $schema.FindClass("user").optionalproperties |? {$_.name -eq 'ExtensionAttribute7'}
            $EA7 | Should -Not -BeNullOrEmpty

        }
    }
        
    Context 'Applications' {
        IT 'VSCode is installed' {
            test-path 'C:\Program Files\Microsoft VS Code\code.exe' | should be $true
        }
        
        IT 'xActiveDirectory module is installed' {
            test-path 'C:\windows\System32\dsa.msc' | should be $true
        }
        
        IT 'xStorage module is installed' {
            test-path 'C:\Program Files\WindowsPowerShell\Modules\xStorage' | should be $true
        }
        
        IT 'pester module is installed' {
            test-path 'C:\Program Files\WindowsPowerShell\Modules\Pester' | should be $true
        }
    }
}