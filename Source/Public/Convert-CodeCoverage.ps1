function Convert-CodeCoverage {
    <#
        .SYNOPSIS
            Convert the file name and line numbers from Pester code coverage of "optimized" modules to the source
        .EXAMPLE
            Invoke-Pester .\Tests -CodeCoverage (Get-ChildItem .\Output -Filter *.psm1).FullName -PassThru |
                Convert-CodeCoverage -SourceRoot .\Source -Relative

            Runs pester tests from a "Tests" subfolder against an optimized module in the "Output" folder,
            piping the results through Convert-CodeCoverage to render the code coverage misses with the source paths.
    #>
    param(
        # The root of the source folder (for resolving source code paths)
        [Parameter(Mandatory)]
        [string]$SourceRoot,

        # The output of `Invoke-Pester -Pasthru`
        # Note: Pester doesn't apply a custom type name
        [Parameter(ValueFromPipeline)]
        [PSObject]$InputObject,

        # Output paths as short paths, relative to the SourceRoot
        [switch]$Relative
    )
    begin {
        $filemap = @{}
        # Conditionally define the Resolve function as either Convert-Path or Resolve-Path
        ${function:Resolve} = if ($Relative) {
            { process {
                    $_ | Resolve-Path -Relative
                } }
        } else {
            { process {
                    $_ | Convert-Path
                } }
        }
    }
    process {
        Push-Location $SourceRoot
        try {
            foreach ($miss in $InputObject.CodeCoverage.MissedCommands ) {
                if (!$filemap.ContainsKey($miss.File)) {
                    # Note: the new pattern is #Region but the old one was # BEGIN
                    $matches = Select-String '^(?:#Region|# BEGIN) (?<ScriptName>.*)(?: (?<LineNumber>\d+))?$' -Path $miss.file
                    $filemap[$miss.File] = @($matches.ForEach( {
                                [PSCustomObject]@{
                                    Line = $_.LineNumber
                                    Path = $_.Matches[0].Groups["ScriptName"].Value.Trim("'") | Resolve
                                }
                            }))
                }
                $hit = $filemap[$miss.file]

                # These are all negative, indicating they are the match *after* the line we're searching for
                # We need the match *before* the line we're searching for
                # And we need it as a zero-based index:
                $index = -2 - [Array]::BinarySearch($filemap[$miss.file].Line, $miss.Line)
                $Source = $filemap[$miss.file][$index]
                $miss.File = $Source.Path
                $miss.Line = $miss.Line - $Source.Line
                $miss
            }
        } finally {
            Pop-Location
        }
    }
}
