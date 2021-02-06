<#
    .SYNOPSIS
        Parses one or more files for aliases and returns a list of alias names.

    .PARAMETER Path
        One or more file that should be parsed for aliases.
#>
function GetCommandAlias {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.IO.FileSystemInfo[]]$Path
    )
    begin {
        $RemovedAliases = @()
        $Result = @()
    }
    process {
        foreach ($currentScript in $Path) {
            $tokens, $parseErrors = $null

            $ast = [System.Management.Automation.Language.Parser]::ParseFile($currentScript, [ref] $tokens, [ref] $parseErrors)

            if ($parseErrors)
            {
                Write-Warning "Failed to parse the public script file $($currentScript.FullName) for aliases."
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

            $commandAsts = $ast.FindAll($astFilter, $true)

            foreach ($aliasCommandAst in $commandAsts) {
                <#
                    Named parameter 'Name' has position parameter 0 in all three commands
                    (New-Alias, Set-Alias, and Remove-Alias). That means that the alias
                    name is in either item 1 (positional) or item 2 (named) in the
                    CommandElements array.
                #>

                # Evaluate if the command uses named parameter Name.
                if ($aliasCommandAst.CommandElements[1] -is [System.Management.Automation.Language.CommandParameterAst]) {
                    # Value is in third item in the array.
                    $aliasName = $aliasCommandAst.CommandElements[2].Value
                }

                # Evaluate if the command uses positional parameter 1.
                if ($aliasCommandAst.CommandElements[1] -is [System.Management.Automation.Language.StringConstantExpressionAst]) {
                    # Value is in second item in the array.
                    $aliasName = $aliasCommandAst.CommandElements[1].Value
                }

                if ($aliasCommandAst.CommandElements[0].Value -eq 'Remove-Alias') {
                    Write-Warning -Message "Found an alias '$aliasName' that is removed using Remove-Alias, assuming the alias should not be exported."

                    <#
                        Save the alias name to the end so that it can be removed from
                        the resulting list of aliases.
                    #>
                    $RemovedAliases += $aliasName
                }
                else {
                    $Result += $aliasName
                }
            }

            # Search for attribute [(Alias())] on parameter blocks.
            $astFilter = {
                $args[0] -is [System.Management.Automation.Language.AttributeAst] `
                -and $args[0].Parent -is [System.Management.Automation.Language.ParamBlockAst] `
                -and $args[0].TypeName.Name -eq 'Alias'
            }

            $attributeAsts = $ast.FindAll($astFilter, $true)

            if ($attributeAsts) {
                $Result += $attributeAsts.PositionalArguments.Value
            }
        }
    }
    end {
        # Return the aliases that wasn't removed.
        $Result | Where-Object -FilterScript { $_ -notin $RemovedAliases }
    }
}
