Describe "UpdateObject" {
    BeforeEach {
        ${Global:Test Values in Spanish} = [PSCustomObject]@{
            One  = "Uno"
            Two  = "Dos"
            Four = "Quatro"
        }

        ${Global:Test Values in French} = [PSCustomObject]@{
            One   = "Un"
            Two   = "Deux"
            Three = "Trois"
            Five  = "Cinq"
        }
    }

    It "Should return the override if the base is empty" {
        $Expected = InModuleScope ModuleBuilder { UpdateObject -Input @{} -Update ${Global:Test Values in French} }
        $Expected.One | Should -Be "Un"
        $Expected.Two | Should -Be "Deux"
        $Expected.Three | Should -Be "Trois"
        $Expected.Four | Should -BeNull
        $Expected.Five | Should -Be "Cinq"
    }

    It "Should return the base if the override is empty" {
        $Expected = InModuleScope ModuleBuilder { UpdateObject -Input ${Global:Test Values in French} -Update @{} }
        $Expected.One | Should -Be "Un"
        $Expected.Two | Should -Be "Deux"
        $Expected.Three | Should -Be "Trois"
        $Expected.Four | Should -BeNull
        $Expected.Five | Should -Be "Cinq"
    }

    It "Should return a combo if we pass both" {
        $Expected = InModuleScope ModuleBuilder { UpdateObject -Input ${Global:Test Values in Spanish} -Update ${Global:Test Values in French} }
        $Expected.One | Should -Be "Un"
        $Expected.Two | Should -Be "Deux"
        $Expected.Three | Should -Be "Trois"
        $Expected.Four | Should -Be "Quatro"
        $Expected.Five | Should -Be "Cinq"
    }

    It "Should preserve important properties" {
        $Expected = InModuleScope ModuleBuilder { UpdateObject -Input ${Global:Test Values in Spanish} -Update ${Global:Test Values in French} -Important Two }
        $Expected.One | Should -Be "Un"
        $Expected.Two | Should -Be "Dos"
        $Expected.Three | Should -Be "Trois"
        $Expected.Four | Should -Be "Quatro"
        $Expected.Five | Should -Be "Cinq"
    }
}
