# Use this file to override the default parameter values used by the `Build-Module`
# command when building the module (see `Get-Help Build-Module -Full` for details).
@{
    Path = "ModuleBuilder.psd1"
    OutputDirectory = "../Output/ModuleBuilder"
    VersionedOutputDirectory = $true
    CopyDirectories = @('en-US')
}
