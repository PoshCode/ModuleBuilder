#Requires -Modules @{ ModuleName = 'InvokeBuild'; ModuleVersion = '5.14.0' }
<#
.SYNOPSIS
    ./project.build.ps1
.EXAMPLE
    Invoke-Build
#>
[CmdletBinding()]
param(
    [ValidateScript(
        {
            Convert-Path @(
                "../../[tT]asks/powershell/base.ps1"
            )
        }
    )]
    $Extends
)

## Self-contained build script - can be invoked directly or via Invoke-Build
if ($MyInvocation.ScriptName -notlike '*Invoke-Build.ps1') {
    Write-Information "Bootstrap Build Dependencies" -Tag "InvokeBuild"
    . (Convert-Path ../*BuildTasks/scripts/Bootstrap.ps1)

    Invoke-Build -File $MyInvocation.MyCommand.Path @PSBoundParameters -Result Result

    if ($Result.Error) {
        $Error[-1].ScriptStackTrace | Out-Host
        exit 1
    }
    exit 0
}

# Define your preferred default build for local dev:
Add-BuildTask . Initialize, Build, Test

# Each build is responsible to define the five core tasks for CI
# But each base adds opinionated tasks to these variables
# So it's usually safe to just use these:
Add-BuildTask Initialize $script:InitializeTasks
Add-BuildTask Build $script:BuildTasks
Add-BuildTask Test $script:TestTasks
Add-BuildTask Publish $script:PublishTasks
Add-BuildTask Push $script:PushTasks
