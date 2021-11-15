TOPIC
    about_ModuleBuilder

SHORT DESCRIPTION
    Common set of tools and patterns for module authoring by the community.

LONG DESCRIPTION
    This project is an attempt by a group of PowerShell MVPs and module authors to:

    - Build a common set of tools for module authoring
    - Encourage a common pattern for organizing PowerShell module projects
    - Promote best practices for authoring functions and modules

    To get started, make sure your module repository looks like the conventions described below, and
    build it using the `Build-Module` command. It will create a versioned folder with an updated Module Manifest and
    the PSM1 file.

    The module is opinionated and expects a few conventions to be respected so that it can:
    - compile the module into a single PSM1 for improved performance
    - execute Pester tests on the built artifact
    - Report correct code coverage against the source's file and line numbers
      (as it was before merging into the single PSM1)
    - bootstrap your repository with required dependencies

    The conventions the module expects and recommends are:
    1. Create a "Source" folder in your repository with a "build.psd1" file and your module manifest in it
    2. In the "build.psd1", specify the relative Path to your module's manifest,  e.g. `@{ Path = "ModuleBuilder.psd1"}`
    3. In your manifest, make sure the "FunctionsToExport" entry is not commented out. You can leave empty.
    5. Within your Source Folder, create the "Private" and "Public" folders for your functions
       For each function of your module, create a file for it. The functions in "Public" will be exported from the module,
       without the extention, so it's important to respect the Verb-Noun format for the name of the files.

    Here is an example from the ModuleBuilder repository.

      ModuleBuilder
        ├───Source
        │   │   build.psd1
        │   │   ModuleBuilder.psd1
        │   │
        │   ├───en-US
        │   │       about_ModuleBuilder.help.txt
        │   ├───Private
        │   │       CopyHelp.ps1
        │   │       CopyReadme.ps1
        │   │       InitializeBuild.ps1
        │   │       ParameterValues.ps1
        │   │       ParseLineNumber.ps1
        │   │       ResolveModuleManifest.ps1
        │   │       ResolveModuleSource.ps1
        │   │       ResolveOutputFolder.ps1
        │   │       SetModuleContent.ps1
        │   └───Public
        │           Build-Module.ps1
        │           Convert-CodeCoverage.ps1
        │           Convert-LineNumber.ps1
        └───Tests
            ├───Private
            │       [...]
            └───Public
                    [...]

EXAMPLES
    PS C:\> Build-Module -SourcePath .\ModuleBuilder\Source\build.psd1

    This will create a versioned folder of the module with ModuleBuilder.psm1 containing all functions
    from the Private and Public folder, an updated ModuleBuilder.psd1 module manifest with the FunctionsToExport
    correctly populated with all functions from the Public Folder.

    ModuleBuilder
      └─── 1.0.0
          │   ModuleBuilder.psd1
          │   ModuleBuilder.psm1
          │
          └───en-US
                about_ModuleBuilder.help.txt


NOTE:
    Thank you to all those who contributed to this module, by writing code, sharing opinions, and provided feedback.

TROUBLESHOOTING NOTE:
    Look out on the Github repository for issues and new releases.

SEE ALSO
  - https://github.com/PoshCode/ModuleBuilder

KEYWORDS
      Module, Build, Task, Template
