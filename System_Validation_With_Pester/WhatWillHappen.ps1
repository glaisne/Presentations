Describe "Examples" {
    Context "Simple tests" {

        it "String test" {
            "test" | Should Be "test"
        }

        it "Will be successfull" {
            Get-ChildItem C:\FolderDoesNotExist -ErrorAction SilentlyContinue
        }

        it "What will happen?" {
            Get-ChildItem C:\FolderDoesNotExist -ErrorAction Continue
        }

        it "Will fail" {
            Get-ChildItem C:\FolderDoesNotExist -ErrorAction Stop
        }

    }
}