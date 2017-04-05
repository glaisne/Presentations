Describe "Should Examples" {
    Context "Possitive Assertions" {
        BeforeAll {
            "This test is a Success" | Out-File TESTDRIVE:\Test.Log -Encoding ascii
            Add-Content -Value '' -Path TESTDRIVE:\Error.log
        }
        it "Should Be" {
            "text" | should be "text"
        }
        it "Should BeExactly" {
            "TeXt" | should BeExactly "TeXt"
        }
        it "Should BeGreaterThan" {
            5      | Should BeGreaterThan 0
        }
        it "Should BeLessThan" {
            0      | Should BeLessThan 5
        }
        it "Should BeLike" {
            "text" | Should BeLike "*x*"
        }
        #it "Should BeLikeExactly " {
        #    "Text" | Should BeLikeExactly "T*"
        #}
        it "should BeOfType" {
            "Text" | Should BeOfType System.String
        }
        it "Should Throw" {
            { 1/0 }   | Should Throw
        }
        it "Should exist" {
            "c:\"  | should exist
        }
        it "Should Contain" {
            'TESTDRIVE:\Test.Log' | should Contain "Success"
        }
        it "Should ContainExactly" {
            'TESTDRIVE:\Test.Log' | should ContainExactly "Success"
        }
        it "should BeNullOrEmpty" {
            [string]::Empty | should BeNullOrEmpty
        }
        it "should beIn" {
            0               | Should BeIn @(0,1,2)
        }
    }

    Context "Negative Assertions" {
        BeforeAll {
            "This test is a Success" | Out-File TESTDRIVE:\Test.Log -Encoding ascii
            Add-Content -Value 'Everything worked!' -Path TESTDRIVE:\Success.log
        }
        it "Should Not Be" {
            "text" | should Not be "text fail"
        }
        it "Should Not BeExactly" {
            "TeXt" | should not BeExactly "Text"
        }
        it "Should Not BeGreaterThan" {
            5      | Should Not BeGreaterThan 6
        }
        it "Should Not BeLessThan" {
            0      | Should Not BeLessThan -5
        }
        it "Should Not BeLike" {
            "text" | Should Not BeLike "*q*"
        }
        #it "Should Not BeExactlyLike" {
        #    "Text" | Should Not BeLikeExactly "E*"
        #}
        it "should Not BeOfType" {
            "Text" | Should Not BeOfType int
        }
        it "Should Not Throw" {
            {1 + 1}  | Should Not Throw
        }
        it "Should Not exist" {
            "c:\DoesNot Exist"  | should Not exist
        }
        it "Should Not Contain" {
            'TESTDRIVE:\Test.log' | should Not Contain "Error"
        }
        it "Should Not ContainExactly" {
            'TESTDRIVE:\Test.log' | should Not ContainExactly "Error" #Case Sensitive
        }
        it "should Not BeNullOrEmpty" {
            'TESTDRIVE:\Success.log' | should Not BeNullOrEmpty
        }
        it "should Not beIn" {
            3      | Should Not BeIn @(0,1,2)
        }
    }
}
