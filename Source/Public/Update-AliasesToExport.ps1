using namespace System.Management.Automation.Language
using namespace System.Collections.Generic

function Update-AliasesToExport {
    <#
        .SYNOPSIS
            A Script Generator to update a module manifest with Alias exports
        .DESCRIPTION
            Update-AliasesToExport will find all the aliases in the root script module and update the AliasesToExport in the module manifest

            This function never outputs any TextReplacements
    #>
    [CmdletBinding()]
    [OutputType([TextReplacement])]
    param(
        # The AST of the root script module to find aliases in
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [Alias("Ast")]
        [Ast]$ScriptModule,

        # The path to the module manifest that should contain the aliases
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string]$ModuleManifest
    )
    begin {
        # This is used only to parse the parameters to New|Set|Remove-Alias
        # It's basically a private part of the implementation of AliasVisitor,
        # but PowerShell does not allow nested classes
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
        class AliasExportGenerator : AstVisitor {
            [HashSet[String]]$Aliases = @()
            [AliasParameterVisitor]$AliasCommandVisitor = @{}

            # Export aliases from the [Alias(...)] attribute on functions
            [AstVisitAction] VisitFunctionDefinition([FunctionDefinitionAst]$ast) {
                @($ast.Body.ParamBlock.Attributes.Where{
                        $_.TypeName.Name -eq "Alias"
                    }.PositionalArguments.Value).ForEach{
                    if ($_) {
                        $this.Aliases.Add($_)
                    }
                }

                # but we can only export aliases that are defined on top-level functions
                return [AstVisitAction]::SkipChildren
            }

            # Export aliases from New|Set|Remove-Alias called outside of functions
            [AstVisitAction] VisitCommand([CommandAst]$ast) {
                if ($ast.CommandElements[0].Value -imatch "(New|Set|Remove)-Alias") {
                    $ast.Visit($this.AliasCommandVisitor.Clear())

                    # We COULD just remove it (even if we didn't add it) ...
                    if ($this.AliasCommandVisitor.Command -ieq "Remove-Alias") {
                        # But Write-Verbose for logging purposes
                        if ($this.Aliases.Contains($this.AliasCommandVisitor.Name)) {
                            Write-Verbose -Message "Alias '$($this.AliasCommandVisitor.Name)' is removed by line $($ast.Extent.StartLineNumber): $($ast.Extent.Text)"
                            $this.Aliases.Remove($this.AliasCommandVisitor.Name)
                        }
                        # We don't export aliases that are (already) explicitly global
                    } elseif ($this.AliasCommandVisitor.Name -and $this.AliasCommandVisitor.Scope -ine 'Global') {
                        $this.Aliases.Add($this.AliasCommandVisitor.Name)
                    }
                }
                return [AstVisitAction]::SkipChildren
            }
        }
    }
    process {
        $Visitor = [AliasExportGenerator]::new()
        $ScriptModule.Visit($Visitor)
        Update-Metadata -Path $ModuleManifest -PropertyName AliasesToExport -Value $Visitor.Aliases
    }
}

