Describe "ParseLineNumber" {
    It 'Should get the ScriptName and LineNumber from stack trace messages with modules' {
        $Source = ParseLineNumber "at Test-Throw<End>, C:\Test\Path\Modules\ErrorMaker\ErrorMaker.psm1: line 27"
        $Source.ScriptName | Should -Be "C:\Test\Path\Modules\ErrorMaker\ErrorMaker.psm1"
        $Source.ScriptLineNumber | Should -Be 27
    }

    It 'Should get the file and line number from stack trace messages with scripts' {
        $Source = ParseLineNumber "at <ScriptBlock>, C:\Test\Path\ErrorMaker.ps1: line 31"
        $Source.ScriptName | Should -Be "C:\Test\Path\ErrorMaker.ps1"
        $Source.ScriptLineNumber | Should -Be 31
    }

    It 'Should get the ScriptName and LineNumber from multi-line PositionMessage with scripts' {
        $Source = ParseLineNumber "At C:\Test\Path\ErrorMaker.ps1:31 char:1
                                   + Test-Exception
                                   + ~~~~~~~~~~~~~~"
        $Source.ScriptName | Should -Be "C:\Test\Path\ErrorMaker.ps1"
        $Source.ScriptLineNumber | Should -Be 31
        $Source.OffsetInLine | Should -Be 1
    }

    It 'Should get the ScriptName and LineNumber from multi-line PositionMessage with modules' {
        $Source = ParseLineNumber "At C:\Test\Path\Modules\ErrorMaker\ErrorMaker.psm1:27 char:4
                                   +    throw 'FourtyTwo'
                                   +    ~~~~~~~~~~~~~~~~~"
        $Source.ScriptName | Should -Be "C:\Test\Path\Modules\ErrorMaker\ErrorMaker.psm1"
        $Source.ScriptLineNumber | Should -Be 27
        $Source.OffsetInLine | Should -Be 4
    }

    It 'Should get the ScriptName and LineNumber from calls that include a ScriptBlock' {
        $Source = ParseLineNumber "at <ScriptBlock>, C:\Test\Path\InvokeError.ps1: line 14"

        $Source.ScriptName | Should -Be "C:\Test\Path\InvokeError.ps1"
        $Source.ScriptLineNumber | Should -Be 14
    }

    It 'Should get the ScriptName and LineNumber from calls that include a ScriptBlock' {
        $Source = ParseLineNumber "at <ScriptBlock>, C:\Test\Path\InvokeError.ps1: line 14"

        $Source.ScriptName | Should -Be "C:\Test\Path\InvokeError.ps1"
        $Source.ScriptLineNumber | Should -Be 14
    }

    It 'Should get <ScriptBlock> and <No file> and line number from errors at the console' {
        $Source = ParseLineNumber "at <ScriptBlock>, <No file>: line 1"

        $Source.ScriptName | Should -Be "<No file>"
        $Source.ScriptLineNumber | Should -Be 1
        $Source.InvocationBlock | Should -Be "<ScriptBlock>"
    }

    It 'Should get the function and file name and line number from lines without <block>' {
        $Source = ParseLineNumber "at ItImpl, C:\Program Files\PowerShell\Modules\Pester\Functions\It.ps1: line 207"

        $Source.ScriptName | Should -Be "C:\Program Files\PowerShell\Modules\Pester\Functions\It.ps1"
        $Source.ScriptLineNumber | Should -Be 207
        $Source.InvocationBlock | Should -Be "ItImpl"
    }
}