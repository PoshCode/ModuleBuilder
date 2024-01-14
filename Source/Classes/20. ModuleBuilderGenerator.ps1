using namespace System.Management.Automation.Language
using namespace System.Collections.Generic
class TextReplace {
    [int]$StartOffset = 0
    [int]$EndOffset = 0
    [string]$Text = ''
}

class ModuleBuilderGenerator {
    hidden [List[TextReplace]]$Replacements = @()

    [void] Replace($StartOffset, $EndOffset, $Text) {
        $this.Replacements.Add([TextReplace]@{
                StartOffset = $StartOffset
                EndOffset   = $EndOffset
                Text        = $Text
            })
    }

    [void] Insert($StartOffset, $Text) {
        $this.Replacements.Add([TextReplace]@{
                StartOffset = $StartOffset
                EndOffset   = $StartOffset
                Text        = $Text
            })
    }

    [ScriptBlock]$Filter = { $true }

    [Ast]$Ast

    hidden [string]$Path

    ModuleBuilderGenerator($Path) {
        $this.Path = $Path
        $this.Ast = ConvertToAst $Path

    }

    AddParameter([ScriptBlock]$FromScriptBlock) {
        [ParameterExtractor]$ExistingParameters = $this.Ast
        [ParameterExtractor]$AdditionalParameters = $FromScriptBlock.Ast

        $Additional = $AdditionalParameters.Parameters.Where{ $_.Name -notin $ExistingParameters.Parameters.Name }
        if (($Text = $Additional.Text -join ",`n`n")) {
            $Replacement = [TextReplace]@{
                StartOffset = $ExistingParameters.InsertOffset
                EndOffset   = $ExistingParameters.InsertOffset
                Text        = if ($ExistingParameters.Parameters.Count -gt 0) {
                    ",`n`n" + $Text
                } else {
                    "`n" + $Text
                }
            }

            Write-Debug "Adding parameters to $($this.Ast.name): $($Additional.Name -join ', ')"
            $this.Replacements.Add($Replacement)
        }
    }



    [List[TextReplace]]Generate([Ast]$ast) {
        $ast.Visit($this)
        return $this.Replacements
    }
}
