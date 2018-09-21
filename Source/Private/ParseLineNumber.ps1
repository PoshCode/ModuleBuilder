function ParseLineNumber {
    <#
        .SYNOPSIS
            Parses the SourceFile and SourceLineNumber from a position message
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
            # At (optional invocation,) <source file>:(maybe " line ") number
            if ($line -match "at(?: (?<InvocationBlock>[^,]+),)?\s+(?<SourceFile>.+):(?<!char:)(?: line )?(?<SourceLineNumber>\d+)(?: char:(?<OffsetInLine>\d+))?") {
                [PSCustomObject]@{
                    PSTypeName       = "Position"
                    SourceFile       = $matches.SourceFile
                    SourceLineNumber = $matches.SourceLineNumber
                    OffsetInLine     = $matches.OffsetInLine
                    PositionMessage  = $line
                    PSScriptRoot     = Split-Path $matches.SourceFile
                    PSCommandPath    = $matches.SourceFile
                    InvocationBlock  = $matches.InvocationBlock
                }
            } elseif($line -notmatch "\s*\+") {
                Write-Warning "Can't match: '$line'"
            }
        }
    }
}