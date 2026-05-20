using namespace System.Management.Automation.Language
using namespace System.Collections.Generic

function ConvertTo-Script {
    <#
        .SYNOPSIS
            A Script Generator which converts a module to a script
        .DESCRIPTION
            ConvertTo-Script takes a script module (which may include assemblies), and the name of a function in that
            module, and generates a script file with the same name as the function -- that actually contains the full
            module (including assemblies), so you can share it as a single-file script.

            It actually copies over the param block and any comments in it, so you get full help for the script.

            NOTE: This Script Generator, only generates NEW FILES, so it does not output any TextReplacements.
        .EXAMPLE
            # The normal way to use ConvertTo-Script is to set it in the build manifest for your module, so you get a
            # module, and a script that you can run directly (and upload to the gallery as a script) at the same time.

            # Set the Generator to ConvertTo-Script, and pass the function name you want to turn into a script
            # You can also pass a GUID to use for the script if you want to make sure future versions use the same ID
            @{
                ModuleManifest  = "./Source/ModuleBuilder.psd1"
                CopyDirectories = @('en-US')
                Generators      = @(
                    @{ Generator = "ConvertTo-Script"; Function = "Build-Module"; GUID = '6b8e5f3a-2c1d-4e7b-9a4f-1c3e5d7b9a2f' }
                )
            }

            # Now, when we build the module with Build-Module it will generate a Build-Module.ps1 script in the output directory!
        .EXAMPLE
            # You can also use it through Invoke-ScriptGenerator if you just want to convert an existing function in a module to a script without building it:

            $null = Invoke-ScriptGenerator -Path "ModuleBuilder/3.2.0/ModuleBuilder.psm1" -Generator "ConvertTo-Script" -Parameters @{ Function = "Build-Module" }
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

        # The GUID to use as the script GUID
        # If not provided a new GUID will be generated
        [guid]$Guid = [guid]::NewGuid(),

        # The path to the script module to convert
        # This is used to find the module manifest,
        # But the the script will be saved in the same location
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string]$Path,

        # File encoding for output RootModule (defaults to UTF8)
        # Converted to System.Text.Encoding for PowerShell 6 (and something else for PowerShell 5)
        [ValidateSet("UTF8", "UTF8Bom", "UTF8NoBom", "UTF7", "ASCII", "Unicode", "UTF32")]
        [string]$Encoding = $(if ($IsCoreCLR) { "UTF8Bom" } else { "UTF8" })
    )
    begin {
        Write-Debug "    ENTER: ConvertTo-Script BEGIN $Path $FunctionName"
        class ParamBlockExtractor : AstVisitor {
            [string]$ParamBlock
            [string]$FunctionName
            [CommentHelpInfo]$HelpInfo

            ParamBlockExtractor([string]$FunctionName) {
                $this.FunctionName = $FunctionName
            }

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

        $SetContentCmd = $ExecutionContext.InvokeCommand.GetCommand('Microsoft.PowerShell.Management\Set-Content', [System.Management.Automation.CommandTypes]::Cmdlet)
        Write-Debug "    EXIT: ConvertTo-Script BEGIN"
    }
    process {
        Write-Debug "    ENTER: ConvertTo-Script PROCESS $Path $FunctionName"
        $Visitor = [ParamBlockExtractor]::new($FunctionName)
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
.GUID $Guid
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
        ) | & $SetContentCmd -Path "$FunctionName.ps1" -Encoding $Encoding

        Update-ScriptFileInfo "$FunctionName.ps1" -Version $Manifest.ModuleVersion -Author $Manifest.Author -CompanyName $Manifest.CompanyName -Copyright $Manifest.Copyright -Tags $Manifest.PrivateData.PSData.Tags -ProjectUri $Manifest.PrivateData.PSData.ProjectUri -LicenseUri $Manifest.PrivateData.PSData.LicenseUri -IconUri $Manifest.PrivateData.PSData.IconUri -ReleaseNotes $Manifest.PrivateData.PSData.ReleaseNotes

        Pop-Location
        Write-Debug "    EXIT: ConvertTo-Script PROCESS"
    }
}

