[CmdletBinding()]
param(
    # The path to the folder where your code to analyze is
    [string]$Path = $((Get-Module ModuleBuilder).ModuleBase),

    # Runs Script Analyzer on the files in the Path directory and all subdirectories recursively.
    [string]$Recurse,

    # The name (or path) of a settings file to be used.
    [string]$Settings = "..\PSScriptAnalyzerSettings.psd1"
)

if ($ModulesToImport) {
    Write-Verbose "Import-Module $ModulesToImport" -Verbose
    Import-Module $ModulesToImport
    $null = $PSBoundParameters.Remove("ModulesToImport")
}
$ExcludeRules = @()
$CustomRulePath = @{}
$RecurseCustomRulePath = $false
if ($Settings) {
    Write-Verbose "Resolve settings '$Settings'" -Verbose
    if (Test-Path $Settings) {
        $Settings = Resolve-Path $Settings
    } else {
        Push-Location
        foreach($directory in Get-ChildItem -Directory) {
            Set-Location $directory
            if (Test-Path $Settings) {
                $Settings = Resolve-Path $Settings
            }
        }
        Pop-Location
    }
    if (!(Test-Path $Settings)) {
        Write-Warning "Could not resolve settings '$Settings'"
        Remove-Variable Settings
        $null = $PSBoundParameters.Remove("Settings")
    } else {
        $Config = Import-LocalizedData -BaseDirectory $pwd -FileName PSScriptAnalyzerSettings
        $ExcludeRules   = @($Config.ExcludeRules)
        $CustomRulePath = @{
            CustomRulePath = @($Config.CustomRulePath)
            RecurseCustomRulePath = [bool]$Config.RecurseCustomRulePath
        }
    }
}

Describe "ScriptAnalyzer" {
    $ScriptAnalyzer = @{
        Config = @{} + $PSBoundParameters
        Rules = Get-ScriptAnalyzerRule | Where-Object RuleName -notin $ExcludeRules
    }

    if ($CustomRulePath) {
        $CustomRulePath | Should Exist
        if ($CustomRules = Get-ScriptAnalyzerRule @CustomRulePath) {
            $ScriptAnalyzer.Rules += $CustomRules
        }
    }

    It "Does not throw while running Script Analyzer" {
        $Config = $ScriptAnalyzer.Config
        try {
            $ScriptAnalyzer.Results = Invoke-ScriptAnalyzer @Config
        } catch {
            Write-Warning "Exception running script analyzer on $($_.TargetObject)"
            Write-Warning $($_.Exception.StackTrace)
            throw
        }
    }

    forEach ($Rule in $ScriptAnalyzer.Rules.RuleName) {
        It "Passes $Rule" {
            if ($Failures = $ScriptAnalyzer.Results.Where( {$_.RuleName -like "*$Rule"})) {
            throw ([Management.Automation.ErrorRecord]::new(
                ([Exception]::new(($Failures.ForEach{$_.ScriptName + ":" + $_.Line + " " + $_.Message} -join "`n"))),
                "ScriptAnalyzerViolation",
                "SyntaxError",
                $Failures))
            }
        }
    }
}
