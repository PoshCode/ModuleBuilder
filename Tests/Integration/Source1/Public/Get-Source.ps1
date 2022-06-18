using module ModuleBuilder

function Get-Source {
    [CmdletBinding()]
    [Alias("gs","gsou")]
    param()
}

New-Alias -Name 'Get-MyAlias' -Value 'Get-ChildItem'
