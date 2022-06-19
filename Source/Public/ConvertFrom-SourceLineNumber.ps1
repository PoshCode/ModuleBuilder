function ConvertFrom-SourceLineNumber {
    <#
        .SYNOPSIS
            Convert a source file path and line number to the line number in the built output
        .EXAMPLE
            ConvertFrom-SourceLineNumber -Module ~\2.0.0\ModuleBuilder.psm1 -SourceFile ~\Source\Public\Build-Module.ps1 -Line 27
    #>
    [CmdletBinding(DefaultParameterSetName="FromString")]
    param(
        # The SourceFile is the source script file that was built into the module
        [Parameter(Mandatory, ValueFromPipelineByPropertyName, Position=0)]
        [Alias("PSCommandPath", "File", "ScriptName", "Script")]
        [string]$SourceFile,

        # The SourceLineNumber (from an InvocationInfo) is the line number in the source file
        [Parameter(Mandatory, ValueFromPipelineByPropertyName, Position=1)]
        [Alias("LineNumber", "Line", "ScriptLineNumber")]
        [int]$SourceLineNumber,

        # The name of the module in memory, or the full path to the module psm1
        [Parameter()]
        [string]$Module
    )
    begin {
        $filemap = @{}
    }
    process {
        if (!$Module) {
            $Command = [IO.Path]::GetFileNameWithoutExtension($SourceFile)
            $Module = (Get-Command $Command -ErrorAction SilentlyContinue).Source
            if (!$Module) {
                Write-Warning "Please specify -Module for ${SourceFile}: $SourceLineNumber"
                return
            }
        }
        if ($Module -and -not (Test-Path $Module)) {
            $Module = (Get-Module $Module -ErrorAction Stop).Path
        }
        # Push-Location (Split-Path $SourceFile)
        try {
            if (!$filemap.ContainsKey($Module)) {
                # Note: the new pattern is #Region but the old one was # BEGIN
                $regions = Select-String '^(?:#Region|# BEGIN) (?<SourceFile>.*) (?<LineNumber>\d+)?$' -Path $Module
                $filemap[$Module] = @($regions.ForEach{
                    [PSCustomObject]@{
                        PSTypeName = "BuildSourceMapping"
                        SourceFile = $_.Matches[0].Groups["SourceFile"].Value.Trim("'")
                        StartLineNumber = $_.LineNumber
                    }
                })
            }

            $hit = $filemap[$Module]

            if ($Source = $hit.Where{ $SourceFile.EndsWith($_.SourceFile.TrimStart(".\")) }) {
                [PSCustomObject]@{
                    PSTypeName = "OutputLocation"
                    Script     = $Module
                    Line       = $Source.StartLineNumber + $SourceLineNumber
                }
            } elseif($Source -eq $Module) {
                [PSCustomObject]@{
                    PSTypeName = "OutputLocation"
                    Script     = $Module
                    Line       = $SourceLineNumber
                }
            } else {
                Write-Warning "'$SourceFile' not found in $Module"
            }
        } finally {
            Pop-Location
        }
    }
}
