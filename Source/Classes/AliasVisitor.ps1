using namespace System.Management.Automation.Language
using namespace System.Collections.Generic

# This is used only to parse the parameters to New|Set|Remove-Alias
# NOTE: this is _part of_ the implementation of AliasVisitor, but ...
#       PowerShell can't handle nested classes so I left it outside,
#       but I kept it here in this file.
class AliasParameterVisitor : AstVisitor {
    [string]$Parameter = $null
    [string]$Command = $null
    [string]$Name = $null
    [string]$Value = $null
    [string]$Scope = $null

    # Parameter Names
    [AstVisitAction] VisitCommandParameter([CommandParameterAst]$ast) {
        $this.Parameter = $ast.ParameterName
        return [AstVisitAction]::Continue
    }

    # Parameter Values
    [AstVisitAction] VisitStringConstantExpression([StringConstantExpressionAst]$ast) {
        # The FIRST command element is always the command name
        if (!$this.Command) {
            $this.Command = $ast.Value
            return [AstVisitAction]::Continue
        } else {
            # Nobody should use minimal parameters like -N for -Name ...
            # But if they do, our parser works anyway!
            switch -Wildcard ($this.Parameter) {
                "S*" {
                    $this.Scope = $ast.Value
                }
                "N*" {
                    $this.Name = $ast.Value
                }
                "Va*" {
                    $this.Value = $ast.Value
                }
                "F*" {
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
                return [AstVisitAction]::StopVisit
            } elseif ($this.Name -and $this.Scope -eq "Global") {
                return [AstVisitAction]::StopVisit
            }
            return [AstVisitAction]::Continue
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
class AliasVisitor : AstVisitor {
    [HashSet[String]]$Aliases = @()
    [AliasParameterVisitor]$Parameters = @{}

    # The [Alias(...)] attribute on functions matters, but we can't export aliases that are defined inside a function
    [AstVisitAction] VisitFunctionDefinition([FunctionDefinitionAst]$ast) {
        @($ast.Body.ParamBlock.Attributes.Where{
            $_.TypeName.Name -eq "Alias"
        }.PositionalArguments.Value).ForEach{
            if ($_) {
                $this.Aliases.Add($_)
            }
        }

        return [AstVisitAction]::SkipChildren
    }

    # Top-level commands matter, but only if they're alias commands
    [AstVisitAction] VisitCommand([CommandAst]$ast) {
        if ($ast.CommandElements[0].Value -imatch "(New|Set|Remove)-Alias") {
            $ast.Visit($this.Parameters.Clear())

            # We COULD just remove it (even if we didn't add it) ...
            if ($this.Parameters.Command -ieq "Remove-Alias") {
                # But Write-Verbose for logging purposes
                if ($this.Aliases.Contains($this.Parameters.Name)) {
                    Write-Verbose -Message "Alias '$($this.Parameters.Name)' is removed by line $($ast.Extent.StartLineNumber): $($ast.Extent.Text)"
                    $this.Aliases.Remove($this.Parameters.Name)
                }
            # We don't need to export global aliases, because they broke out already
            } elseif ($this.Parameters.Name -and $this.Parameters.Scope -ine 'Global') {
                $this.Aliases.Add($this.Parameters.Name)
            }
        }
        return [AstVisitAction]::SkipChildren
    }
}
