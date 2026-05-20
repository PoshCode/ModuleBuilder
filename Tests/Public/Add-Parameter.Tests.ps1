Describe "Add-Parameter" {
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

                function Get-Date {
                    param(
                        # The Date Format String
                        [string]$Format = "o"
                    )
                    [DateTime]::Now.ToString($Format)
                }
            }

            # Use Invoke-ScriptGenerator instead of calling Add-Parameter directly, to get the result of the transformation as text
            $result = Invoke-ScriptGenerator -Code $source -Generator Add-Parameter -Parameters @{
                FunctionName = "Show-*"
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
            $showDate.Body.ParamBlock.Parameters.Name.VariablePath.UserPath |
                Should -Be @('Format', 'ForegroundColor', 'BackgroundColor')

            $showUserName | Should -Not -BeNullOrEmpty
            $showUserName.Body.ParamBlock.Parameters.Name.VariablePath.UserPath |
                Should -Be @('ForegroundColor', 'BackgroundColor')

            # Get-Date Should not be modified, since it does not match the FunctionName filter
            $getDate = $Ast.Find({
                    param($node)
                    $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
                    $node.Name -eq 'Get-Date'
                }, $true)
            $getDate | Should -Not -BeNullOrEmpty
            $getDate.Body.ParamBlock.Parameters.Name.VariablePath.UserPath |
                Should -Be @('Format')
        }
    }
}
