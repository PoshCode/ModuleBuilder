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

### Building from source

[![Build Status](https://github.com/PoshCode/ModuleBuilder/actions/workflows/build.yml/badge.svg)](https://github.com/PoshCode/ModuleBuilder/actions/workflows/build.yml)

The easiest, fastest build uses [Earthbuild](https://docs.earthbuild.dev/). Earthbuilds use containers to ensure tools are available, to parallelize steps, and to cache output. On Windows, it requires WSL2, Docker Desktop, and of course, the Earthbuild CLI. If you already have those installed, you can just check out this repository and run `earth +test` to build and run the tests.

```powershell
git clone https://github.com/PoshCode/ModuleBuilder.git
cd ModuleBuilder
earth +test
```

#### Building without Earthbuild

The full ModuleBuilder build depends on the [dotnet](https://dotnet.microsoft.com) SDK, and has a few other build-time dependencies, including [Invoke-Build](https://github.com/nightroman/Invoke-Build) for orchestrating the build steps, [Pester](https://github.com/Pester/Pester) to test it, and [Install-ModuleFast](https://github.com/JustinGrote/ModuleFast) to install the rest of the dependencies. All of those (including dotnet) are handled _for you_ in the Earthbuild build, but without it you need to install dotnet separately.

To build without Earthbuild, you will need to install dotnet, and then clone this repository and our shared [Tasks](https://github.com/PoshCode/Tasks) repository such that the `Tasks` folder is a sibling of the `ModuleBuilder` folder:

```powershell
git clone https://github.com/PoshCode/ModuleBuilder.git
git clone https://github.com/PoshCode/Tasks.git
```

Once you've cloned both, the `build.build.ps1` script will install the other dependencies (see [build.requires.psd1](https://github.com/PoshCode/ModuleBuilder/blob/main/build.requires.psd1)), and will build and test the module.

```powershell
cd ModuleBuilder
./build.build.ps1
```

This _should_ work on Windows, Linux, or MacOS. I test the build process on Windows, and in CI we run it in the Linux containers via Earthbuild, and we run _the full Pester test suite_ on all three platforms.

## Most recent releases

### 3.2.0 - Script Generators

Script Generators let developers modify their module's source code as it is being built. A generator can create new script functions on the fly, such that whole functions are added to the built module. A generator can also inject boilerplate code like error handling, logging, tracing and timing at build-time, so this code can be maintained once, and be automatically added (and updated) in all the places where it's needed when the module is built. The generators run during the build and can inspect existing functions, data files, or even data from an API, and produce code that is output into the module (and clearly marked as generated).

The normal way to use Script Generators is to just pass configuration when calling `Build-Module`. For example, look at how [FromGitHub](https://github.com/Jaykul/FromGitHub) passes `Generators` to `Build-Module` in its `build.psd1` file so that it produces both a FromGitHub module, and a Install-FromGitHub script:

```PowerShell
    Generators = @(
        @{ Generator = "ConvertTo-Script"; Function = "Install-FromGitHub"; GUID = '23addf96-d1d7-4f51-b97f-c4f0189263b6' }
    )
```

There are a pair of built-in generators included in ModuleBuilder, which are designed around Aspect-Oriented Programming (AOP) principles, and another pair that were extracted from the existing ModuleBuilder functionality, as well as one that came from my old `RequiredModules` project. You can write custom generators to do almost anything you can imagine. The built-in generators are implemented as public functions so that you can `Get-Help` to get examples of how to use them, and of course, their source code is available for you to read and learn from.

The bottom line is that each Script Generator will get called by `Build-Module` at the end of the build process, and will be passed any configuration, as well as the AST of the module as it exists so far. The generators then output `TestReplacement` objects which represent the changes they want to make to the code, and the `Invoke-ScriptGenerator` handles applying those changes and updating the code and AST before calling the next generator.

Of course, you should be careful if you're using generators, because they're still PowerShell scripts, and they can do whatever they want. One of the included examples generates a totally new script file, and another modifies the manifest instead of the actual module code.

#### Merge-ScriptBlock

This generator takes `boilerplate` code that can be wrapped around the content of the begin/process/end script blocks of the functions in a module. You can specify one or more wildcard patterns to determine which functions are affected. This is generally used for adding cross-cutting concerns like error handling, logging, tracing and timing to all your functions without having to maintain that code separately in each function.

#### Add-Parameter

This generator goes along with Merge-ScriptBlock. It copies parameters from one script function to another. The idea is to allow the creation of common parameter sets across your modules, with any implementation details encapsulated in the code you would add with Merge-ScriptBlock. Have a look at [TerminalBlocks](https://github.com/Jaykul/TerminalBlocks/blob/feature/simplify/build.psd1) for an example of this -- it allowed me to write _very simple_ functions, but code-generate a large part of the implementation as common parameters and common rendering code.

#### Move-UsingStatement

This simple generator comments out `using` statements in the source files, sorts them, and puts a unique copy of each statement at the top of the final module file. This allows you to have `using` statements in each function in your source files, but have them consolidated at the top of the Build-Module output module.

#### Update-AliasesToExport

This generator is a real edge case example. It doesn't actually modify the source code at all -- but rather modifies the module manifest to update the list of exported aliases based on the `[Alias()]` attributes and `New-Alias` and `Set-Alias` (and`Remove-Alias`) commands. In ModuleBuilder, this ensures that any aliases you declare in the source files get properly exported from the final module when you use Build-Module.

### ConvertTo-Script

This generator is a type of packaging script. It takes a full module (including assemblies), and the name of a single function from that module. Then it outputs a script file named for that function (with the same parameters as the function), that contains the entire module embedded within it, such that the single script file can be distributed alone, and even run from a network share without needing to install the module. I wrote this when I was working on `Install-RequiredModules` and `Install-FromGitHub`.

### 3.1.0 - Supports help outside the top of script commands

Starting with this release, ModuleBuilder adds an empty line between the `#REGION filename` comment lines it injects, and the content of the files. This allows PowerShell to recognize help comments that are at the top of each file (outside the function block).

### 3.0.0 - Better alias support

Starting with this release, ModuleBuilder will automatically export aliases from `New-Alias` and `Set-Alias` as well as the `[Alias()]` attributes on commands. This is (probably not) a breaking change, but because it can change the aliases exported by existing modules that use ModuleBuilder, I've bumped the major version number as a precaution (if you're reading this, mission accomplished).

Additionally, the `Build-Module` command now _explicitly sorts_ the source files into alphabetical order, to ensure consistent behavior regardless of the native order of the underlying file system. This is technically also a breaking change, but it's unlikely to affect anyone except the people whose builds didn't work on non-Windows systems because of the previous behavior.
