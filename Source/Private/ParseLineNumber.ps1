function ParseLineNumber {
    <#
        .SYNOPSIS
            Parses the ScriptName and ScriptLineNumber from a position message
        .DESCRIPTION
            Parses messages like:
                at <ScriptBlock>, <No file>: line 1
                at C:\Test\Path\ErrorMaker.ps1:31 char:1
                at C:\Test\Path\Modules\ErrorMaker\ErrorMaker.psm1:27 char:4
    #>
    [Cmdletbinding()]
    param(
        # A position message, starting with "at ..." and containing a line number
        [Parameter(ValueFromPipeline)]
        [string]$PositionMessage
    )
    process {
        foreach($line in $PositionMessage -split "\r?\n") {
            if ($line -match "at(?: (?<InvocationBlock>[^,]+),)?\s+(?<ScriptName>.+):(?<!char:)(?: line )?(?<ScriptLineNumber>\d+)(?: char:(?<OffsetInLine>\d+))?") {
                [PSCustomObject]@{
                    PSTypeName       = "Position"
                    ScriptName       = $matches.ScriptName
                    ScriptLineNumber = $matches.ScriptLineNumber
                    OffsetInLine     = $matches.OffsetInLine
                    PositionMessage  = $line
                    PSScriptRoot     = Split-Path $matches.ScriptName
                    PSCommandPath    = $matches.ScriptName
                    InvocationBlock  = $matches.InvocationBlock
                }
            } elseif($line -notmatch "\s*\+") {
                Write-Warning "Can't match: '$line'"
            }
        }
    }
}