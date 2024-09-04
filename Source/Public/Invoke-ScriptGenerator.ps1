using namespace System.Text

function Invoke-ScriptGenerator {
    <#
        .SYNOPSIS
            Generate code using Script Generator functions
        .DESCRIPTION
            Script Generators let developers modify source code as it is being built.

            A generator can create new script functions on the fly, such that whole functions are added to the built module, or can inject boilerplate code like error handling, logging, tracing and timing at build-time, so this code can be maintained once, and be automatically added (and updated) in all the places where it's needed when the module is built.

            This command is run internally by Build-Module if you pass Generator configuration to it.
        .EXAMPLE
            $Boilerplate = @'
                param(
                    # The Foreground Color (name, #rrggbb, etc)
                    [Alias('Fg')]
                    [PoshCode.Pansies.RgbColor]$ForegroundColor,

                    # The Background Color (name, #rrggbb, etc)
                    [Alias('Bg')]
                    [PoshCode.Pansies.RgbColor]$BackgroundColor
                )
                $ForegroundColor.ToVt() + $BackgroundColor.ToVt($true) + (
                Use-OriginalBlock
                ) +"`e[0m" # Reset colors
            '@

            # Or use a file path instead
            $Code = {
                function Show-Date {
                    param(
                        # The text to display
                        [string]$Format
                    )
                    Get-Date -Format $Format
                }
            }

            @(  @{ Generator = "Add-Parameter";     FunctionName = "*"; Boilerplate = $Boilerplate }
                @{ Generator = "Merge-ScriptBlock"; FunctionName = "*"; Boilerplate = $Boilerplate }
            ) | Invoke-ScriptGenerator $Code
    #>
    [CmdletBinding(DefaultParameterSetName = "Code")]
    param(
        # The script content, script, function info, or file path to parse
        [Parameter(ParameterSetName = "Code", Position = 0)]
        [ScriptBlock]$Code,

        [Parameter(ParameterSetName = "Path", Position = 0)]
        [Alias("PSPath", "File")]
        [string]$Path,

        # The name of the Script Generator to invoke. Must be a command that takes an AST as a pipeline inputand outputs TextReplacement objects.
        # There are two built into ModuleBuilder:
        # - MergeBlocks. Supports Before/After/Around blocks for aspects like error handling or authentication.
        # - Add-Parameter. Supports adding parameters to functions (usually in conjunction with MergeBlock that use those parameters)
        [Parameter(ValueFromPipelineByPropertyName)]
        [string]$Generator,

        # Additional configuration parameters for the generator
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [hashtable]$Parameters,

        # If set, will overwrite the Source with the generated content.
        # Use with care, as this will modify the source file!
        [switch]$Overwrite
    )
    begin {
        $AstParam = @{} + $PSBoundParameters
        $null = $AstParam.Remove("Overwrite")
        $null = $AstParam.Remove("Generator")
        $null = $AstParam.Remove("Parameters")
        $ParseResults = ConvertToAst @AstParam
        [StringBuilder]$Builder = $ParseResults.Ast.Extent.Text
    }
    process {
        if (-not $PSBoundParameters.ContainsKey("Generator") -and $Parameters.ContainsKey("Generator")) {
            $Generator = $Parameters["Generator"]
            $null = $Parameters.Remove("Generator")
        }
        Write-Debug "Invoking $Generator generator for $($ParseResults.Path) ($Path) with @{$($Parameters.Keys.ForEach{ $_ } -join ', ')}"

        # To make things more usable, resolve paths to "boilerplate" or "template" files based on our BoilerplateDirectory (alias TemplateDirectory)
        try {
            if ($Parameters.ContainsKey("Boilerplate")) {
                # If there's a Boilerplate parameter and it does not point at a file, check in the BoilerplateDirectory, and update it, if we find it.
                if ($Parameters.Boilerplate -and -not (Test-Path $Parameters.Boilerplate)) {
                    if ($BoilerPlate = Join-Path $BoilerplateDirectory $Parameters.Boilerplate | Where-Object { Test-Path $_ }) {
                        $Parameters.Boilerplate = $BoilerPlate
                    }
                }
                Write-Debug "Boilerplate = $($Parameters.Boilerplate)"
            } elseif ($Parameters.ContainsKey("Template")) {
                # If there's a Template parameter and it does not point at a file, check in the BoilerplateDirectory, and update it, if we find it.
                if ($Parameters.Template -and -not (Test-Path $Parameters.Template)) {
                    if ($Template = Join-Path $BoilerplateDirectory $Parameters.Template | Where-Object { Test-Path $_ }) {
                        $Parameters.Template = $Template
                    }
                }
                Write-Debug "Template = $($Parameters.Template)"
            }
        } catch {
            Write-Debug "Could not resolve the Boilerplate/Template"
        }

        if (-not $Generator) {
            Write-Error "Generator missconfiguration. The Generator name is mandatory."
            continue
        }

        # Find that generator...
        $GeneratorCmd = Get-Command -Name ${Generator} -ParameterType Ast -ErrorAction Ignore <# -CommandType Function #>
        | Where-Object { $_.OutputType.Name -eq "TextReplacement" -or ($_.CommandType -eq "Alias" -and $_.Definition -like "PesterMock*" ) }
        | Select-Object -First 1

        if (-not $GeneratorCmd) {
            Write-Error "Generator missconfiguration. Unable to find Generator = '$Generator'"
            continue
        }

        Write-Verbose "Generating $GeneratorCmd in $($ParseResults.Path) $(if($Parameters.Count){"`n                    with $($Parameters.GetEnumerator().ForEach{ $_.Key + ' = ' + ($_.Value -join ", ") } -join "`n                     and ")"})"
        #! Process replacements from the bottom up, so the line numbers work
        foreach ($Replacement in $ParseResults | & $GeneratorCmd @Parameters | Sort-Object StartOffset -Descending) {
            $Builder = $Builder.Remove($replacement.StartOffset, ($replacement.EndOffset - $replacement.StartOffset)).Insert($replacement.StartOffset, $replacement.Text)
        }

        #! If we're looping through multiple generators, we have to parse the new version of the source
        if ($MyInvocation.ExpectingInput) {
            # Update the AST
            $ParseResults = ConvertToAst -Code $Builder.ToString() -Path $ParseResults.Path
            # In case a Generator tries to use the actual files, update the content
            Set-Content $ParseResults.Path $Builder
        }
    }
    end {
        Write-Debug "Overwrite: $Overwrite and it's a file: $([bool]$ParseResults.Path) (Content is $($Builder.Length) long)"
        if ($Overwrite -and $ParseResults.Path) {
            Set-Content $ParseResults.Path $Builder
        } else {
            $Builder.ToString()
        }
    }
}
