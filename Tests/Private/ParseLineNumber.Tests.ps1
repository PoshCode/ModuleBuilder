#requires -Module ModuleBuilder
Describe "ParseLineNumber" {

    It 'Should get the SourceFile and LineNumber from stack trace messages with modules' {
        $Source = InModuleScope ModuleBuilder { ParseLineNumber "at Test-Throw<End>, C:\Test\Path\Modules\ErrorMaker\ErrorMaker.psm1: line 27" }
        $Source.SourceFile | Should -Be "C:\Test\Path\Modules\ErrorMaker\ErrorMaker.psm1"
        $Source.SourceLineNumber | Should -Be 27
    }

    It 'Should get the file and line number from stack trace messages with scripts' {
        $Source = InModuleScope ModuleBuilder { ParseLineNumber "at <ScriptBlock>, C:\Test\Path\ErrorMaker.ps1: line 31" }
        $Source.SourceFile | Should -Be "C:\Test\Path\ErrorMaker.ps1"
        $Source.SourceLineNumber | Should -Be 31
    }

    It 'Should get the SourceFile and LineNumber from multi-line PositionMessage with scripts' {
        $Source = InModuleScope ModuleBuilder { ParseLineNumber "At C:\Test\Path\ErrorMaker.ps1:31 char:1
                                                                 + Test-Exception
                                                                 + ~~~~~~~~~~~~~~" }
        $Source.SourceFile | Should -Be "C:\Test\Path\ErrorMaker.ps1"
        $Source.SourceLineNumber | Should -Be 31
        $Source.OffsetInLine | Should -Be 1
    }

    It 'Should get the SourceFile and LineNumber from multi-line PositionMessage with modules' {
        $Source = InModuleScope ModuleBuilder { ParseLineNumber "At C:\Test\Path\Modules\ErrorMaker\ErrorMaker.psm1:27 char:4
                                                                 +    throw 'FourtyTwo'
                                                                 +    ~~~~~~~~~~~~~~~~~" }
        $Source.SourceFile | Should -Be "C:\Test\Path\Modules\ErrorMaker\ErrorMaker.psm1"
        $Source.SourceLineNumber | Should -Be 27
        $Source.OffsetInLine | Should -Be 4
    }

    It 'Should get the SourceFile and LineNumber from calls that include a ScriptBlock' {
        $Source = InModuleScope ModuleBuilder { ParseLineNumber "at <ScriptBlock>, C:\Test\Path\InvokeError.ps1: line 14" }

        $Source.SourceFile | Should -Be "C:\Test\Path\InvokeError.ps1"
        $Source.SourceLineNumber | Should -Be 14
    }

    It 'Should get the SourceFile and LineNumber from calls that include a ScriptBlock' {
        $Source = InModuleScope ModuleBuilder { ParseLineNumber "at <ScriptBlock>, C:\Test\Path\InvokeError.ps1: line 14" }

        $Source.SourceFile | Should -Be "C:\Test\Path\InvokeError.ps1"
        $Source.SourceLineNumber | Should -Be 14
    }

    It 'Should get <ScriptBlock> and <No file> and line number from errors at the console' {
        $Source = InModuleScope ModuleBuilder { ParseLineNumber "at <ScriptBlock>, <No file>: line 1" }

        $Source.SourceFile | Should -Be "<No file>"
        $Source.SourceLineNumber | Should -Be 1
        $Source.InvocationBlock | Should -Be "<ScriptBlock>"
    }

    It 'Should get the function and file name and line number from lines without <block>' {
        $Source = InModuleScope ModuleBuilder { ParseLineNumber "at ItImpl, C:\Program Files\PowerShell\Modules\Pester\Functions\It.ps1: line 207" }

        $Source.SourceFile | Should -Be "C:\Program Files\PowerShell\Modules\Pester\Functions\It.ps1"
        $Source.SourceLineNumber | Should -Be 207
        $Source.InvocationBlock | Should -Be "ItImpl"
    }
}
