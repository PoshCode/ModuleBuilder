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
            $InputObject.CodeCoverage.MissedCommands | Convert-LineNumber -Passthru |
                Select-Object SourceFile, @{Name="Line"; Expr={$_.SourceLineNumber}}, Command
        } finally {
            Pop-Location
        }
    }
}
