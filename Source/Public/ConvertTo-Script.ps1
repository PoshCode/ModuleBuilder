using namespace System.Management.Automation.Language
using namespace System.Collections.Generic

function ConvertTo-Script {
    <#
        .SYNOPSIS
            A Script Generator which converts a module to a script
        .DESCRIPTION
            ConvertTo-Script takes a script module (which may include dotnet assemblies),
            and generates a script file with the module and libraries embedded and ready to run.

            You should provide the name of a function from the module that will be invoked when the script is run.

            In this way you can package any module into a script which invokes a specific command in that module.

            This function never outputs any TextReplacements.
    #>
    [CmdletBinding()]
    [OutputType([TextReplacement])]
    param(
        # The AST of the script module to convert to a script
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [Alias("Ast")]
        [Ast]$ScriptModule,

        # The name of a function in the module to invoke when the script is run
        [Parameter(Mandatory)]
        [string]$FunctionName,

        # The path to the script module to convert
        # This is used to find the module manifest,
        # But the the script will be saved in the same location
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string]$Path
    )
    begin {
        Write-Debug "    ENTER: ConvertTo-Script BEGIN $Path $FunctionName"
        class ParamBlockExtractor : AstVisitor {
            [string]$ParamBlock
            [string]$FunctionName
            [CommentHelpInfo]$HelpInfo

            [AstVisitAction] VisitParamBlock([ParamBlockAst]$ast) {
                if ($ast.Parameters) {
                    $this.ParamBlock = @(@($ast.Attributes.Extent.Text) + $ast.Extent.Text) -join "`n"
                }
                return [AstVisitAction]::StopVisit
            }

            [AstVisitAction] VisitFunctionDefinition([FunctionDefinitionAst]$ast) {
                if ($ast.Name -ne $this.FunctionName) {
                    return [AstVisitAction]::SkipChildren
                }
                $this.HelpInfo = $ast.GetHelpContent()
                return [AstVisitAction]::Continue
            }
        }
        Write-Debug "    EXIT: ConvertTo-Script BEGIN"
    }
    process {
        Write-Debug "    ENTER: ConvertTo-Script PROCESS $Path $FunctionName"
        $Visitor = [ParamBlockExtractor]@{
            FunctionName = $FunctionName
        }
        $ScriptModule.Visit($Visitor)

        Write-Debug "      Parse Module Manifest: $Path"
        $ModuleManifest = [IO.Path]::ChangeExtension($Path, '.psd1')
        Write-Debug "      Parse Module Manifest: $ModuleManifest"
        $Manifest = ConvertFrom-Metadata $ModuleManifest

        if (!$Visitor.ParamBlock) {
            Write-Error "ConvertTo-Script: Could not find function $FunctionName in $Path"
        }

        Push-Location (Split-Path $ModuleManifest -Parent)
        if (Test-Path "$FunctionName.ps1") {
            Write-Warning "Overwriting existing script $FunctionName.ps1"
        }
        @(
            @"
<#PSScriptInfo
.VERSION 0.0.0
.GUID $([guid]::newguid())
.AUTHOR anonymous
.COMPANYNAME
.COPYRIGHT
.TAGS
.LICENSEURI
.PROJECTURI
.ICONURI
.EXTERNALMODULEDEPENDENCIES
.REQUIREDSCRIPTS
.EXTERNALSCRIPTDEPENDENCIES
.RELEASENOTES
.PRIVATEDATA
#>

"@
            $Visitor.HelpInfo.GetCommentBlock()
            $Visitor.ParamBlock
            "`n"
            @(
                if ($Manifest.RequiredAssemblies) {
                    Get-ChildItem $Manifest.RequiredAssemblies
                }
                Get-Item $Path
            ) | CompressToBase64 -ExpandScriptName ImportBase64Module
            "$FunctionName @PSBoundParameters"
        ) | Set-Content "$FunctionName.ps1"

        Update-ScriptFileInfo "$FunctionName.ps1" -Version $Manifest.ModuleVersion -Author $Manifest.Author -CompanyName $Manifest.CompanyName -Copyright $Manifest.Copyright -Tags $Manifest.PrivateData.PSData.Tags -ProjectUri $Manifest.PrivateData.PSData.ProjectUri -LicenseUri $Manifest.PrivateData.PSData.LicenseUri -IconUri $Manifest.PrivateData.PSData.IconUri -ReleaseNotes $Manifest.PrivateData.PSData.ReleaseNotes

        Pop-Location
        Write-Debug "    EXIT: ConvertTo-Script PROCESS"
    }
}

