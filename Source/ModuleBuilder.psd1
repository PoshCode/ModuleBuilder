@{
    ModuleVersion          = "1.0.0.0"

    # Modules that must be imported into the global environment prior to importing this module
    RequiredModules        = @()

    FunctionsToExport      = @()

    # ID used to uniquely identify this module
    GUID                   = '4775ad56-8f64-432f-8da7-87ddf7a34653'
    Description            = 'A module for authoring and building PowerShell modules'

    # The main script module that is automatically loaded as part of this module
    RootModule             = 'ModuleBuilder.psm1'

    # Common stuff for all our modules:
    CompanyName            = 'PoshCode.org'
    Author                 = 'Joel Bennett'
    Copyright              = "Copyright 2018 Joel Bennett"

    # Minimum version of the Windows PowerShell engine required by this module
    PowerShellVersion      = '5.1'
    # Minimum version of the .NET Framework required by this module
    DotNetFrameworkVersion = '4.0'
    # Minimum version of the common language runtime (CLR) required by this module
    CLRVersion             = '4.0.30319'
}
