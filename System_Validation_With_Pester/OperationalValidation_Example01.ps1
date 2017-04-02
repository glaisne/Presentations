Describe "Describe" {
    BeforeEach {
        Write-host "Describe: BeforeEach"
    }

    Context "Context" {
        BeforeEach {
            Write-host "Context : BeforeEach"
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
    }
}