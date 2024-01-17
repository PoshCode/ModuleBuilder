<#
.SYNOPSIS
    ./project.build.ps1
.EXAMPLE
    Invoke-Build
.NOTES
    0.5.0 - Parameterize
    Add parameters to this script to control the build
#>
[CmdletBinding()]
param(
    # dotnet build configuration parameter (Debug or Release)
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Release',

    # Add the clean task before the default build
    [switch]$Clean,

    # Collect code coverage when tests are run
    [switch]$CollectCoverage,

    # Which projects to build
    [Alias("Projects")]
    $dotnetProjects = @(),

    # Which projects are test projects
    [Alias("TestProjects")]
    $dotnetTestProjects = @(),

    # Further options to pass to dotnet
    [Alias("Options")]
    $dotnetOptions = @{
        "-verbosity" = "minimal"
        # "-runtime" = "linux-x64"
    }
)
$InformationPreference = "Continue"
$ErrorView = 'DetailedView'

# The name of the module to publish
$script:PSModuleName = "TerminalBlocks"
# Use Env because Earthly can override it
$Env:OUTPUT_ROOT ??= Join-Path $BuildRoot Modules

$Tasks = "Tasks", "../Tasks", "../../Tasks" | Convert-Path -ErrorAction Ignore | Select-Object -First 1
Write-Information "$($PSStyle.Foreground.BrightCyan)Found shared tasks in $Tasks" -Tag "InvokeBuild"
## Self-contained build script - can be invoked directly or via Invoke-Build
if ($MyInvocation.ScriptName -notlike '*Invoke-Build.ps1') {
    & "$Tasks/_Bootstrap.ps1"

    Invoke-Build -File $MyInvocation.MyCommand.Path @PSBoundParameters -Result Result

    if ($Result.Error) {
        $Error[-1].ScriptStackTrace | Out-String
        exit 1
    }
    exit 0
}

## The first task defined is the default task. Put the right values for your project type here...
if ($dotnetProjects -and $Clean) {
    Add-BuildTask CleanBuild Clean, ($Task ?? "Test")
} elseif ($Clean) {
    Add-BuildTask CleanBuild Clean, ($Task ?? "Test")
}

## Initialize the build variables, and import shared tasks, including DotNet tasks
. "$Tasks/_Initialize.ps1"
