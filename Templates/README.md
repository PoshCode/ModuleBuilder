# Generators

This directory contains (template based) generators that allow end-users to easily
generate new Powershell Modules following ModuleBuilder best practices and thus:

- folder structure
- default settings

## Dotnet

After cloning this repository (and assuming you have the dotnet SDK installed),
you can install the ModuleBuilder templates from this folder by running:

```posh
dotnet new -i ./
```

We need to publish this to nuget to make installing it easier.

Once you've installed the template(s), you can use the `PSModuleBuilder`
[template](https://github.com/dotnet/templating) to generate a new module in an empty folder using:

```posh
dotnet new PSModuleBuilder
```

Or you can create the module folder with `-o` and set the module author, company and description like this:

```posh
dotnet new PSModuleBuilder -o MyNewModule --author Jaykul --company PoshCode.org --description "My Brand New Module"
```

Even better, you can create some defaults for yourself using the alias option:

```posh
dotnet new -a psmo psmodulebuilder --author Jaykul --company PoshCode.org
```

And then create a new module like this:

```posh
dotnet new psmo -o MyNewModule --description "My Brand New Module"
```
