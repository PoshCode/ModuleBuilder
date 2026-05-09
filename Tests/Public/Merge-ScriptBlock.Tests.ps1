Describe "Merge-ScriptBlock" {
    Context "Example 1. Adding parameters to functions" {
        It "Adds boilerplate parameters to functions" {
            $boilerplate = {
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
                ) + "`e[0m" # Reset colors
            }

            $source = {
                function Show-Date {
                    param(
                        # The Date Format String
                        [string]$Format = "o"
                    )
                    Get-Date -Format $Format
                }

                function Show-UserName {
                    [OutputType([string])]
                    [CmdletBinding(DefaultParameterSetName = "SimpleFormat")]
                    param()
                    [Environment]::UserName
                }
            }

            # Use Invoke-ScriptGenerator instead of calling Merge-ScriptBlock directly, to get the result of the transformation as text
            $result = Invoke-ScriptGenerator -Code $source -Generator Merge-ScriptBlock -Parameters @{
                FunctionName = "*"
                Boilerplate  = $boilerplate
            }

            $Tokens = $null
            $ParseErrors = $null
            $Ast = [System.Management.Automation.Language.Parser]::ParseInput($result, $Path, [ref]$Tokens, [ref]$ParseErrors)
            $ParseErrors | Should -BeNullOrEmpty
            $Ast | Should -Not -BeNullOrEmpty

            # it should add those two parameters to both functions, without modifying the existing parameter
            $showDate = $Ast.Find({
                    param($node)
                    $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
                    $node.Name -eq 'Show-Date'
                }, $true)

            $showUserName = $Ast.Find({
                    param($node)
                    $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
                    $node.Name -eq 'Show-UserName'
                }, $true)


            $showDate | Should -Not -BeNullOrEmpty
            $showDate.Body.EndBlock -split "`n"
            | ForEach-Object { $_.Trim() }
            | Select-Object -Skip 1
            | Select-Object -First 3
            | Should -Be @(
                "`$ForegroundColor.ToVt() + `$BackgroundColor.ToVt(`$true) + ("
                "Get-Date -Format `$Format"
                ") + `"``e[0m`""
            )

            $showUserName | Should -Not -BeNullOrEmpty
            $showUserName.Body.EndBlock -split "`n"
            | ForEach-Object { $_.Trim() }
            | Select-Object -Skip 1
            | Select-Object -First 3
            | Should -Be @(
                "`$ForegroundColor.ToVt() + `$BackgroundColor.ToVt(`$true) + ("
                "[Environment]::UserName"
                ") + `"``e[0m`""
            )
        }
    }
}
