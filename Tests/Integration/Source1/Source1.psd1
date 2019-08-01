@{
    # The module version should be SemVer.org compatible
    ModuleVersion          = "1.0.0"

    # PrivateData is where all third-party metadata goes
    PrivateData            = @{
        # PrivateData.PSData is the PowerShell Gallery data
        PSData             = @{
            # Prerelease string should be here, so we can set it
            Prerelease     = ''

            # Release Notes have to be here, so we can update them
            ReleaseNotes   = '
            A test module
            '

            # Tags applied to this module. These help with module discovery in online galleries.
            Tags           = 'Authoring','Build','Development','BestPractices'

            # A URL to the license for this module.
            LicenseUri     = 'https://github.com/PoshCode/ModuleBuilder/blob/master/LICENSE'

            # A URL to the main website for this project.
            ProjectUri     = 'https://github.com/PoshCode/ModuleBuilder'

            # A URL to an icon representing this module.
            IconUri        = 'https://github.com/PoshCode/ModuleBuilder/blob/resources/ModuleBuilder.png?raw=true'
        } # End of PSData
    } # End of PrivateData

    # The main script module that is automatically loaded as part of this module
    RootModule             = 'Source1.psm1'

    # Modules that must be imported into the global environment prior to importing this module
    RequiredModules        = @()

    # Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
    DefaultCommandPrefix = 'Source'

    # Always define FunctionsToExport as an empty @() which will be replaced on build
    FunctionsToExport      = @()
    AliasesToExport        = @()

    # ID used to uniquely identify this module
    GUID                   = 'a264e183-e0f7-4219-bc80-c30d14e0e98e'
    Description            = 'A module for authoring and building PowerShell modules'

    # Common stuff for all our modules:
    CompanyName            = 'PoshCode'
    Author                 = 'Joel Bennett'
    Copyright              = "Copyright 2018 Joel Bennett"

    # Minimum version of the Windows PowerShell engine required by this module
    PowerShellVersion      = '5.1'
    CompatiblePSEditions = @('Core','Desktop')
}
