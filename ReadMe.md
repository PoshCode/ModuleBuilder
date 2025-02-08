# Module Builder - Simplifying Authoring PowerShell (Script) Modules

This module makes it easier to break up your module source into several files for organization, even though you need to ship it as one big psm1 file.

There are still some issues in Visual Studio Code and PSScriptAnalyzer when authoring modules as multiple files, but if you want to break up your module into multiple files for organization and maintainability, and still need to ship it as one big file for performance and compatibility reasons, this module is for you.

## You should ship your module as one big file!

PowerShell expects script modules to be all in one file. A module in a single `.psm1` script file results in the best performance, natural "script" scope, and full support for classes and "using" statements.

The single file option is particularly important for performance if you are signing your module (or your end users want to be able to code-sign it), because each file's signature must be checked, and each certificate must be checked against CRLs. It's also critical if you are using PowerShell classes (the `using` statement only supports classes defined in the root psm1 file). It's basically required if you want to use module-scope variables to share state between functions in your module.

## What's in the ModuleBuilder module so far?

This module is the main output of the project, consisting of one primary command: `Build-Module` and a few helpers to translate input and output line numbers so you can trouble-shoot error messages from your module against the source files.

### Build-Module

Builds a script module from a source project containing one file per function in `Public` and `Private` folders.

The `Build-Module` command is a build task for PowerShell script modules that supports [incremental builds](https://docs.microsoft.com/en-us/visualstudio/msbuild/incremental-builds).

### Convert-CodeCoverage

Takes the output from `Invoke-Pester -Passthru` run against the build output, and converts the code coverage report to the source lines.

### ConvertFrom-SourceLineNumber

Converts a line number from a source file to the corresponding line number in the built output.

### ConvertTo-SourceLineNumber

Converts a line number from the built output to the corresponding file and line number in the source.

### Convert-Breakpoint

Convert any breakpoints on source files to module files _and vice-versa_.

## Organizing Your Module

For best results, you need to organize your module project similarly to how this project is organized. It doesn't have to be exact, because you can override nearly all of our conventions, but the module _is_ opinionated, so if you follow the conventions, it should feel wonderfully automatic.

1. Create a `source` (or `src`) folder with a `build.psd1` file and your module manifest in it
2. In the `build.psd1` specify the relative **Path** to your module's manifest, e.g. `@{ Path = "ModuleBuilder.psd1" }`
3. In your manifest, make sure a few values are not commented out. You can leave them empty, because they'll be overwritten:
    - `FunctionsToExport` will be updated with the _file names_ that match the `PublicFilter`
    - `AliasesToExport` will be updated with the values from `[Alias()]` attributes on commands
    - `Prerelease` and `ReleaseNotes` in the `PSData` hash table in `PrivateData`

Once you start working on the module, you'll create sub-folders in source, and put script files in them with only **one** function in each file. You should name the files with _the same name_ as the function that's in them -- especially in the `source\public` folder, where we use the file names to determine the exported functions.

1. By convention, use SourceDirectories named "Classes" (and/or "Enum"), "Private", and "Public"
2. By convention, the PublicFilter is all of the functions in the "Public" directory.
3. To force classes to be in a certain order, you can prefix their file names with numbers, like `01-User.ps1`

There are a _lot_ of conventions in `Build-Module`, expressed as default values for its parameters. These defaults are documented in the help for Build-Module, and you can override any parameter defaults by adding keys to the `build.psd1` file with your preferences, or by passing the values to the `Build-Module` command directly. So in other words, you can override the default `SourceDirectories` and `PublicFilters` (and any others) by adding them to the `build.psd1` file.

## A note on build tools

There are several PowerShell build frameworks available. The build task in ModuleBuilder doesn't particularly endorse or interoperate with any of them, but it does accomplish a particular task that is needed by all of them.

A good build framework needs to support [incremental builds](https://docs.microsoft.com/en-us/visualstudio/msbuild/incremental-builds) and have a way to define build targets which have dependencies on other targets, such that it can infer the [target build order](https://docs.microsoft.com/en-us/visualstudio/msbuild/msbuild-targets#target-build-order).

A good build framework should also include pre-defined tasks for most common build targets, including restoring dependencies, cleaning old output, building and assembling a module from source, testing that module, and publishing the module for public consumption.  Our `Build-Module` command, for instance, is just one task of several which would be needed for a build target for a PowerShell script module.

We are currently using the [Invoke-Build](https://github.com/nightroman/Invoke-Build) and [earthly](https://docs.earthly.dev/) to build this module.

### Building from source

[![Build Status](https://github.com/PoshCode/ModuleBuilder/actions/workflows/build.yml/badge.svg)](https://github.com/PoshCode/ModuleBuilder/actions/workflows/build.yml)

The easiest, fastest build uses [earthly](https://docs.earthly.dev/). Earthly builds use containers to ensure tools are available, parallelize steps, and to cache their output. On Windows, it requires WSL2, Docker Desktop, and of course, the earthly CLI. If you already have those installed, you can just check out this repository and run `earthly +test` to build and run the tests.

```powershell
git clone https://github.com/PoshCode/ModuleBuilder.git
cd ModuleBuilder
earthly +test
```

#### Building without earthly

The full ModuleBuilder build has a lot of dependencies which are handled _for you_, in the Earthly build, like dotnet, gitversion, and several PowerShell modules. To build without it you will need to clone the PoshCode shared "Tasks" repository which contains shared Invoke-Build tasks into the same parent folder, so that the `Tasks` folder is a sibling of the `ModuleBuilder` folder:

```powershell
git clone https://github.com/PoshCode/ModuleBuilder.git
git clone https://github.com/PoshCode/Tasks.git
```

Once you've cloned both, the `Build.build.ps1` script will use the shared [Tasks\_Bootstrap.ps1](https://github.com/PoshCode/Tasks/blob/main/_Bootstrap.ps1) to install the other dependencies (see [build.requires.psd1](https://github.com/PoshCode/ModuleBuilder/blob/main/build.requires.psd1)), including [dotnet](https://dot.net), and will use [Invoke-Build](https://github.com/nightroman/Invoke-Build) and [Pester](https://github.com/Pester/Pester) to build and test the module.

```powershell
cd ModuleBuilder
./Build.build.ps1
```

This _should_ work on Windows, Linux, or MacOS. I test the build process on Windows, and in CI we run it in the Linux containers via earthly, and we run the full Pester test suit on all three platforms.

## Most recent releases

### 3.2.0 - Script Generators

Script Generators let developers modify their module's source code as it is being built. A generator can create new script functions on the fly, such that whole functions are added to the built module. A generator can also inject boilerplate code like error handling, logging, tracing and timing at build-time, so this code can be maintained once, and be automatically added (and updated) in all the places where it's needed when the module is built. The generators run during the build and can inspect existing functions, data files, or even data from an API, and produce code that is output into the module (and clearly marked as generated).

### 3.1.0 - Supports help outside the top of script commands

Starting with this release, ModuleBuilder adds an empty line between the `#REGION filename` comment lines it injects, and the content of the files. This allows PowerShell to recognize help comments that are at the top of each file (outside the function block).

### 3.0.0 - Better alias support

Starting with this release, ModuleBuilder will automatically export aliases from `New-Alias` and `Set-Alias` as well as the `[Alias()]` attributes on commands. This is (probably not) a breaking change, but because it can change the aliases exported by existing modules that use ModuleBuilder, I've bumped the major version number as a precaution (if you're reading this, mission accomplished).

Additionally, the `Build-Module` command now _explicitly sorts_ the source files into alphabetical order, to ensure consistent behavior regardless of the native order of the underlying file system. This is technically also a breaking change, but it's unlikely to affect anyone except the people whose builds didn't work on non-Windows systems because of the previous behavior.
