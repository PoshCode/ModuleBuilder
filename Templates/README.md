# Generators

This directory contains (template based) generators that allow end-users to easily
generate new Powershell Modules following ModuleBuilder best practices and thus:

- folder structure
- default settings

## Dotnet

After installing ModuleBuilder, users can use the `ModuleBuilderModule`
[dotnet template](https://github.com/dotnet/templating) to generate
new modules using:

```posh
dotnet new ModuleBuilderModule -o GeneratedModule --moduleName MyGeneratedModule
```

or without user interaction:

```posh
dotnet new ModuleBuilderModule -o GeneratedModule --moduleName MyGeneratedModule --allow-scripts yes
```
