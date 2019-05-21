# {moduleName}

## Requirements

```posh
Install-Script -Name Install-RequiredModule
```

## Building your module

1. run `Install-RequiredModule`

2. add `.ps1` script files to the `Source` folder

3. run `Build-Module .\Source`

4. compiled module appears in the `Output` folder

## Versioning

ModuleBuilder will automatically apply the next semver version
if you have installed [gitversion](https://gitversion.readthedocs.io/en/latest/).

To manually create a new version run `Build-Module .\Source -SemVer 0.0.2`

## Additional Information

https://github.com/PoshCode/ModuleBuilder
