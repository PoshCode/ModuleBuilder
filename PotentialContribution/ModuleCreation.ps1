

$rootPath = 'D:\ps\test'
$moduleName = "Test"

$modulePath = Join-Path $rootPath $moduleName
$helpPath = Join-Path $modulePath en-US

$HelpFile = Join-Path $helpPath "$moduleName.psm1-help.xml"

New-Item -ItemType Directory $helpPath -Force #create both module folder and help folder

New-ModuleManifest $modulePath -RootModule "$moduleName.psm1" -ModuleVersion 0.0.0.1

New-Item -Path $modulePath -Name "${moduleName}_${guid}_HelpInfo.xml" -ItemType File -Value "" ## templated, get guid from psd1
New-Item -Path $helpPath -Name "$moduleName.psm1-help.xml" -ItemType File -Value "" #pull value from template some place


#inject templated files
#look in content\module
## assumed variables based on Replace: $moduleName, $ShortDescription

iex ("@`"`n{0}`n`"@" -f (gc .\ReadMe.md -Raw)) | Out-File ReadMe.md
cp .\module.psm1 $moduleName.psm1
