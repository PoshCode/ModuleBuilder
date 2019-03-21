# The Module Builder Project

This project is an attempt by a group of PowerShell MVPs and module authors to:

1. Build a common set of [tools for module authoring](#whats-in-the-module-so-far)
2. Encourage a common pattern for [organizing PowerShell module projects](#organizing-your-module)
3. Promote best practices for authoring functions and modules

In short, we want to make it easier for people to write great code and produce great modules.

In service of this goal, we intend to produce:

1. Guidance on using the best of the existing tools: dotnet, Pester, PSDepends, etc.
2. Module templates demonstrating best practices for organization
3. Function templates demonstrating best practices for common parameters and error handling
4. ModuleBuilder module - a set of tools for building modules following these best practices

## The ModuleBuilder module

This module is the first concrete step in the project (although it currently consists of only two commands). It represents the collaboration of several MVPs and module authors who had each written their own version of these tools for themselves, and have now decided to collaborate on creating a shared toolset. We are each using the patterns and tools that are represented here, and are committed to helping others to succeed at doing so.

### Building from source

[![Build Status](https://poshcode.visualstudio.com/ModuleBuilder/_apis/build/status/ModuleBuilder)](https://poshcode.visualstudio.com/ModuleBuilder/_build/latest?definitionId=1)

#### 1. Get the source, obviously

```powershell
git clone https://github.com/PoshCode/ModuleBuilder.git
cd Modulebuilder
```

#### 2. Install dependencies

We have a few modules which are required for building. They're listed in `RequiredModules.psd1` -- the `.\Install-RequiredModule.ps1` script installs them (it defaults to CurrentUser scope, but has a `-Scope` parameter if you're running elevated and want to install them for the `AllUsers`). They only change rarely, so you won't need to run this repeatedly.

```powershell
.\Install-RequiredModule.ps1
```

#### 3. Run the `build.ps1` script.

```powershell
.\build.ps1
```

#### 4. Make the compiled module available to Powershell

The `.\build.ps1` process will output the path to the folder named with the current version number, like "1.0.0" -- the compiled psm1 and psd1 files are in that folder. In order for PowerShell to find them when you ask it to import, they need to be in the PSModulePath.  PowerShell expects to find modules in a folder with a matching name that sits in one of the folders in your PSModulePath.

Since we cloned the "ModuleBuilder" project into a "ModuleBuilder" folder, the easiest thing to do is just add the parent of the `ModuleBuilder` folder to your PSModulePath. Personally, I keep all my git repos in my user folder at `~\Projects` and I add that to my PSModulePath in my profile script. You could do it temporarily for your current PowerShell session by running this:

```powershell
$Env:PSModulePath += ';' + (Resolve-Path ..)
```

Alternatively, you could copy the build output to your PSModulePath -- but then you need to start by creating the new "ModuleBuilder" folder to put the version number folder in. You could do that as you build by running something like this instead of just running the `.\build.ps1` script:

```powershell
$UserModules = Join-Path (Split-Path $Profile.CurrentUserAllHosts) "Modules\ModuleBuilder"
New-Item $UserModules -Type Directory -Force
Copy-Item (.\build.ps1) -Destination $UserModules -Force
```

You final directory stucture Would look something like this: `C:\Users\Jaykul\Documents\PowerShell\Modules\ModuleBuilder\1.0.0\`

#### 5. Run tests with Pester

```powershell
Invoke-Pester
```
Note: If Pester completely fails you likely haven't loaded the module properly. Try running `Import-Module ModuleBuilder` and see step 4.

### What's in the module, so far:

#### `Build-Module`

Builds a script module from a source project containing one file per function in `Public` and `Private` folders.

The `Build-Module` command is a build task for PowerShell script modules that supports [incremental builds](https://docs.microsoft.com/en-us/visualstudio/msbuild/incremental-builds).

#### `Convert-CodeCoverage`

Takes the output from `Invoke-Pester -Passthru` run against the build output, and converts the code coverage report to the source lines.

## A note on build tools

There are several PowerShell build frameworks available. The build task in ModuleBuilder doesn't particularly endorse or interoperate with any of them, but it does accomplish a particular task that is needed by all of them.

A good build framework needs to support [incremental builds](https://docs.microsoft.com/en-us/visualstudio/msbuild/incremental-builds) and have a way to define build targets which have dependencies on other targets, such that it can infer the [target build order](https://docs.microsoft.com/en-us/visualstudio/msbuild/msbuild-targets#target-build-order).

A good build framework should also include pre-defined tasks for most common build targets, including restoring dependencies, cleaning old output, building and assembling a module from source, testing that module, and publishing the module for public consumption.  Our `Build-Module` command, for instance, is just one task of several which would be needed for a build target for a PowerShell script module.


## Organizing Your Module

For best results, you need to organize your module project similarly to how this project is organized. It doesn't have to be exact, because nearly all of our conventions can be overriden, but the module *is* opinionated, so if you follow the conventions, it should feel wonderfully automatic.

1. Create a `source` folder with a `build.psd1` file and your module manifest in it
2. In the `build.psd1` specify the relative **Path** to your module's manifest, e.g. `@{ Path = "ModuleBuilder.psd1" }`
3. In your manifest, make sure the `FunctionsToExport` entry is not commented out. You can leave it empty

Once you start working on the module, you'll create sub-folders in source, and put script files in them with only **one** function in each file. You should name the files with _the same name_ as the function that's in them -- especially in the public folder, where we use the file name (without the extension) to determine the exported functions.

1. By convention, use folders named "Classes", "Private", and "Public"
2. By convention, the functions in "Public" will be exported from the module
3. To force classes to be in a certain order, you can prefix their file names with numbers, like `01-User.ps1`

There are a *lot* of conventions in `Build-Module`, expressed as default values for its parameters. You can set any parameter to `Build-Module` by adding keys to the `build.psd1` file with your preferences. Check the help for Build-Module for details.
