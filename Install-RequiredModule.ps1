Push-Location $PSScriptRoot

# Some people only have a really old version of PowerShellGet that doesn't support pre-release modules
if (!(Get-Command Install-Module -ParameterName 'AllowPrerelease' -ErrorAction 'SilentlyContinue')) {
    $Module = Install-Module 'PowerShellGet' -Repository 'PSGallery' -MaximumVersion 2.99 -MinimumVersion 2.2.5 -Force -Scope CurrentUser -PassThru
    Remove-Module PowerShellGet
    Import-Module PowerShellGet -MinimumVersion $Module.Version -Force
}

try {
    $Script = Install-Script Install-RequiredModule -PassThru -Force
    & (Join-Path $Script.InstalledLocation Install-RequiredModule.ps1)
} finally {
    Pop-Location
}
