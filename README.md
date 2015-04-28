ModuleBuilder
=============

A PowerShell Module to help scripters write, version, sign, package, and publish.

# Goals/Ideas #

The primary goal of this module is to increase the ease and consistency of PowerShell module creation as well as provide a structure to the project that makes it easy for others to contribute and for the owners to integrate those changes in.

Take a look at the **[wiki](https://github.com/PoshCode/ModuleBuilder/wiki)** for more details


# Features #

### Module Creation ###
-------

- Build folder, psd1/psm1
- Create/link github repo
- Setup GitHub
	- Support Templates? (package all the info below)
	- Build Pages site
		- Push help files there? (seperate cmdlet part of 'release' that changes function online help path etc etc)
	- Build Wiki
		- Insert basic docs that represent best practice for community contributions, how to build dev env, submition formats etc
		- Build common sections (FAQ,Contact,etc)
	- Create Tag types for community standard (Some sort of indication that the issue submitter is willing to create the resolution/feature)
	- Create ReadMe.md
		- Inject a todo/checklist for the creator to help guide them (based on template/project type)
- Be aware of an Icon/Logo?
- Wizard driven (UI to run cmdlets for you)

## Module Management ##
- Version management
- Help file creation/publication (github pages?)
	- Create a default About_*ModuleName* help file
	- Convert Comment based help to xml/lang based help
- Auto (cmdlet based) add functions/files to psd1/psm1 (internals ignore by naming convention?)
	- Assume ps1's are function files and add to psm1 to load?

## File Tools ##
- Clean files (expand alias, formatting type stuff)
- Run against PSAnalyzer?
- Function Builder (GUI based tool to build functions shells/params)
	- Also spews XML based help file

## Testing ##
- Help build tests? 
- Insert test folder with first basic test?
- Allow for AppVeyor setup (yml file)

## Sign ##
- Automatically sign scripts upon release

## package ##
- Create a package (oneget/nuget/whatever)


## Release ##
- Publish as a release on github, choco, psgallery

# Next Steps #
1. Define workflows
2. Design workflow (what are the steps to build/publish)
3. Design cmdlets to address that workflow
4. Create Template Data
5. Build Tests
6. Build Functions