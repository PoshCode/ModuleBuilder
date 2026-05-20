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
Write-Information "$($PSStyle.Foreground.BrightMagenta)build.build.ps1$($PSStyle.Reset)"

## Self-contained build script - can be invoked directly or via Invoke-Build
if ($MyInvocation.ScriptName -notlike '*Invoke-Build.ps1') {
    & (Convert-Path ../../[tT]asks/scripts/Invoke-Build.ps1) -File $MyInvocation.MyCommand.Path @PSBoundParameters -Result Result

    if ($Result.Error) {
        $Error[-1].ScriptStackTrace | Out-Host
        exit 1
    }
    exit 0
}

Write-Information "$($PSStyle.Foreground.BrightMagenta)Define Tasks$($PSStyle.Reset)"

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
