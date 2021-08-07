function Convert-Breakpoint {
    <#
        .SYNOPSIS
            Convert any breakpoints on source files to module files and vice-versa
    #>
    [CmdletBinding(DefaultParameterSetName="All")]
    param(
        [Parameter(ParameterSetName="Module")]
        [switch]$ModuleOnly,
        [Parameter(ParameterSetName="Source")]
        [switch]$SourceOnly
    )

    if (!$SourceOnly) {
        foreach ($ModuleBreakPoint in Get-PSBreakpoint | ConvertFrom-SourceLineNumber) {
            Set-PSBreakpoint -Script $ModuleBreakPoint.Script -Line $ModuleBreakPoint.Line
            if ($ModuleOnly) {
                # TODO: | Remove-PSBreakpoint
            }
        }
    }

    if (!$ModuleOnly) {
        foreach ($SourceBreakPoint in Get-PSBreakpoint | ConvertTo-SourceLineNumber) {
            if (!(Test-Path $SourceBreakPoint.SourceFile)) {
                Write-Warning "Can't find source path: $($SourceBreakPoint.SourceFile)"
            } else {
                Set-PSBreakpoint -Script $SourceBreakPoint.SourceFile -Line $SourceBreakPoint.SourceLineNumber
            }
            if ($SourceOnly) {
                # TODO: | Remove-PSBreakpoint
            }
        }
    }
}
