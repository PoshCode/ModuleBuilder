# This is used only to parse the parameters to New|Set|Remove-Alias
class AliasParameterVisitor : System.Management.Automation.Language.AstVisitor {
    [string]$Parameter = $null
    [string]$Command = $null
    [string]$Name = $null
    [string]$Value = $null
    [string]$Scope = $null

    # Parameter Names
    [System.Management.Automation.Language.AstVisitAction] VisitCommandParameter([System.Management.Automation.Language.CommandParameterAst]$ast) {
        $this.Parameter = $ast.ParameterName
        return [System.Management.Automation.Language.AstVisitAction]::Continue
    }

    # Parameter Values
    [System.Management.Automation.Language.AstVisitAction] VisitStringConstantExpression([System.Management.Automation.Language.StringConstantExpressionAst]$ast) {
        # The FIRST command element is always the command name
        if (!$this.Command) {
            $this.Command = $ast.Value
            return [System.Management.Automation.Language.AstVisitAction]::Continue
        } else {
            switch ($this.Parameter) {
                "Scope" {
                    $this.Scope = $ast.Value
                }
                "Name" {
                    $this.Name = $ast.Value
                }
                "Value" {
                    $this.Value = $ast.Value
                }
                "Force" {
                    if ($ast.Value) {
                        # Force parameter was passed as named parameter with a positional parameter after it which is alias name
                        $this.Name = $ast.Value
                    }
                }
                default {
                    if (!$this.Parameter) {
                        # For bare arguments, the order is Name, Value:
                        if (!$this.Name) {
                            $this.Name = $ast.Value
                        } else {
                            $this.Value = $ast.Value
                        }
                    }
                }
            }

            $this.Parameter = $null

            # If we have enough information, stop the visit
            # For -Scope global or Remove-Alias, we don't want to export these
            if ($this.Name -and $this.Command -eq "Remove-Alias") {
                $this.Command = "Remove-Alias"
                return [System.Management.Automation.Language.AstVisitAction]::StopVisit
            } elseif ($this.Name -and $this.Scope -eq "Global") {
                return [System.Management.Automation.Language.AstVisitAction]::StopVisit
            }
            return [System.Management.Automation.Language.AstVisitAction]::Continue
        }
    }

    [AliasParameterVisitor] Clear() {
        $this.Command = $null
        $this.Parameter = $null
        $this.Name = $null
        $this.Value = $null
        $this.Scope = $null
        return $this
    }
}

# This visits everything at the top level of the script
class AliasVisitor : System.Management.Automation.Language.AstVisitor {
    [System.Collections.Generic.HashSet[String]]$Aliases = @()
    [AliasParameterVisitor]$Parameters = @{}

    # The [Alias(...)] attribute on functions matters, but we can't export aliases that are defined inside a function
    [System.Management.Automation.Language.AstVisitAction] VisitFunctionDefinition([System.Management.Automation.Language.FunctionDefinitionAst]$ast) {
        @($ast.Body.ParamBlock.Attributes.Where{ $_.TypeName.Name -eq "Alias" }.PositionalArguments.Value).ForEach({ if ($_) { $this.Aliases.Add($_) } })
        return [System.Management.Automation.Language.AstVisitAction]::SkipChildren
    }

    # Top-level commands matter, but only if they're alias commands
    [System.Management.Automation.Language.AstVisitAction] VisitCommand([System.Management.Automation.Language.CommandAst]$ast) {
        if ($ast.CommandElements[0].Value -imatch "(New|Set|Remove)-Alias") {
            $ast.Visit($this.Parameters.Clear())
            if ($this.Parameters.Command -ieq "Remove-Alias") {
                Write-Warning -Message "Found an alias '$($this.Parameters.Name)' that is removed using $($this.Parameters.Command), assuming the alias should not be exported."

                $this.Aliases.Remove($this.Parameters.Name)
            } elseif ($this.Parameters.Scope -ine 'Global') {
                if ($this.Parameters.Name -notin $this.Aliases)
                {
                    $this.Aliases.Add($this.Parameters.Name)
                }
            }
        }
        return [System.Management.Automation.Language.AstVisitAction]::SkipChildren
    }
}

function GetCommandAlias {
    <#
        .SYNOPSIS
            Parses one or more files for aliases and returns a list of alias names.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param(
        # The AST to find aliases in
        [Parameter(Mandatory, ValueFromPipelineByPropertyName, ValueFromPipeline)]
        [System.Management.Automation.Language.Ast]$Ast
    )
    begin {
        $Visitor = [AliasVisitor]::new()
    }
    process {
        $Ast.Visit($Visitor)
    }
    end {
        $Visitor.Aliases
    }
}

