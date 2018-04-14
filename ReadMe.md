# The Module Builder Project

This project is an attempt by a group of PowerShell MVPs and module authors to:

1. Build a common set of tools for module authoring
2. Encourage a common pattern for organizing PowerShell module projects
3. Promote best practices for authoring functions and modules

In short, we want to make it easier for people to write great code and produce great modules.

In service of this goal, we intend to produce:

1. Guidance on using the best of the existing tools: dotnet, Pester, PSDepends, etc.
2. Module templates demonstrating best practices for organization
3. Function templates demonstrating best practices for common parameters and error handling
4. ModuleBuilder module - a set of tools for building modules following these best practices


## The ModuleBuilder module

This module is the first concrete step in the project (although it currently consists of only a single command). It represents the collaboration of several MVPs and module authors who had each written their own version of these tools for themselves, and have now decided to collaborate on creating a shared toolset. We are each using the patterns and tools that are represented here, and are committed to helping others to succeed at doing so.

### Commands

#### `Build-Module`

Builds a script module from a source project containing one file per function in `Public` and `Private` folders.

The `Build-Module` command is a build task for PowerShell script modules that supports [incremental builds](https://docs.microsoft.com/en-us/visualstudio/msbuild/incremental-builds).

#### `Convert-CodeCoverage`

Takes the output from `Invoke-Pester -Passthru` run against the build output, and converts the code coverage report to the source lines.

## A note on build tools

There are several PowerShell build frameworks available. The build task in ModuleBuilder doesn't particularly endorse or interoperate with any of them, but it does accomplish a particular task that is needed by all of them.

A good build framework needs to support [incremental builds](https://docs.microsoft.com/en-us/visualstudio/msbuild/incremental-builds) and have a way to define build targets which have dependencies on other targets, such that it can infer the [target build order](https://docs.microsoft.com/en-us/visualstudio/msbuild/msbuild-targets#target-build-order).

A good build framework should also include pre-defined tasks for most common build targets, including restoring dependencies, cleaning old output, building and assembling a module from source, testing that module, and publishing the module for public consumption.  Our `Build-Module` command, for instance, is just one task of several which would be needed for a build target for a PowerShell script module.
