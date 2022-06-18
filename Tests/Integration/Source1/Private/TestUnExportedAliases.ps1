function TestUnExportedAliases {
    [CmdletBinding()]
    param()

    New-Alias -Name 'New-NotExportedAlias1' -Value 'Write-Verbose'
    Set-Alias -Name 'New-NotExportedAlias2' -Value 'Write-Verbose'
}

New-Alias -Name 'New-NotExportedAlias3' -Value 'Write-Verbose' -Scope Global
Set-Alias -Name 'New-NotExportedAlias4' -Value 'Write-Verbose' -Scope Global

New-Alias -Name 'New-NotExportedAlias5' -Value 'Write-Verbose'
Remove-Alias -Name 'New-NotExportedAlias5'
