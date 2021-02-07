function GetCommandAlias {
    <#
        .SYNOPSIS
            Parses one or more files for aliases and returns a list of alias names.
    #>
    [CmdletBinding()]
    param(
        # Path to the PSM1 file to amend
        [Parameter(Mandatory, ValueFromPipelineByPropertyName, ValueFromPipeline)]
        [System.Management.Automation.Language.Ast]$AST
    )
    begin {
        $RemovedAliases = @()
        $Result = [Ordered]@{}
    }
    process {
        foreach($function in $AST.FindAll(
            { $Args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] },
            $false )
        ) {
            $Result[$function.Name] = $function.Body.ParamBlock.Attributes.Where{
                $_.TypeName.Name -eq "Alias" }.PositionalArguments.Value
        }

        <#
            Search for New-Alias, Set-Alias, and Remove-Alias.

            The parents for a script level command is:
                - PipelineAst
                - NamedBlockAst
                - ScriptBlockAst
                - $null

            While a command in a function has more parents:
                - PipelineAst
                - NamedBlockAst
                - ScriptBlockAst
                - FunctionDefinitionAst
                - ...
        #>
        $astFilter = {
            $args[0] -is [System.Management.Automation.Language.CommandAst] `
            -and $args[0].CommandElements.StringConstantType -eq 'BareWord' `
            -and $args[0].CommandElements.Value -match '(New|Set|Remove)-Alias' `
            -and $null -eq $args[0].Parent.Parent.Parent.Parent # Make sure it exist at script level
        }

        $commandAsts = $AST.FindAll($astFilter, $true)

        foreach ($aliasCommandAst in $commandAsts) {
            <#
                Named parameter 'Name' has position parameter 0 in all three commands
                (New-Alias, Set-Alias, and Remove-Alias). That means that the alias
                name is in either item 1 if positional or in any other element in the
                array if named.

                Scope must always be a named parameter.
            #>

            $isGlobal = $false

            # Evaluate if the command uses named parameter Scope set to Global. Always start at second element.
            1..($aliasCommandAst.CommandElements.Count - 1) | ForEach-Object -Process {
                if ($aliasCommandAst.CommandElements[$_] -is [System.Management.Automation.Language.CommandParameterAst] `
                    -and $aliasCommandAst.CommandElements[$_].ParameterName -eq 'Scope'
                ) {
                    # Value (the scope) is in the next item in the array.
                    if ($aliasCommandAst.CommandElements[$_ + 1].Value -eq 'Global') {
                        $isGlobal = $true
                    }
                }
            }

            if (-not $isGlobal) {
                $aliasName = $null

                # Evaluate if the command uses positional parameter 1.
                if ($aliasCommandAst.CommandElements[1] -is [System.Management.Automation.Language.StringConstantExpressionAst]) {
                    # Value is in second item in the array.
                    $aliasName = $aliasCommandAst.CommandElements[1].Value
                } else {
                    # Evaluate if the command uses named parameter Name. Always start at second element.
                    1..($aliasCommandAst.CommandElements.Count - 1) | ForEach-Object -Process {
                        if ($aliasCommandAst.CommandElements[$_] -is [System.Management.Automation.Language.CommandParameterAst] `
                            -and $aliasCommandAst.CommandElements[$_].ParameterName -eq 'Name'
                        ) {
                            # Value (the alias name) is in the next item in the array.
                            $aliasName = $aliasCommandAst.CommandElements[$_ + 1].Value
                        }
                    }
                }

                if ($aliasCommandAst.CommandElements[0].Value -eq 'Remove-Alias') {
                    Write-Warning -Message "Found an alias '$aliasName' that is removed using Remove-Alias, assuming the alias should not be exported."

                    <#
                        Save the alias name to the end so that it can be removed from
                        the resulting list of aliases.
                    #>
                    $RemovedAliases += $aliasName
                } else {
                    $Result[$aliasName] = $aliasName
                }
            }
        }
    }
    end {
        # Return the aliases after filtering out those that was removed by `Remove-Alias`.
        $Result | Where-Object -FilterScript { $_.Keys -notin $RemovedAliases }
    }
}
