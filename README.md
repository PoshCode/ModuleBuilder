ModuleBuilder
=============

A PowerShell Module to help scripters write, version, sign, package, and publish.

# Goals/Ideas #

## Module Creation ##
- Build folder, psd1/psm1
- Create/link github repo
- Setup GitHub
	- Support Templates? (package all the info below)
	- Build Pages site
		- Push help files there? (seperate cmdlet part of 'release' that changes function online help path etc etc)
	- Build Wiki
		- Insert basic docs that represent best practice for community contributions, how to build dev env, submition formats etc
		- Build common sections (FAQ,Contact,etc)
	- Create Tag types for community standard
	- Create ReadMe.md
		- Inject a todo/checklist for the creator to help guide them (based on template/project type)
- Be aware of an Icon/Logo?
- Wizard driven (UI to run cmdlets for you)

## Module Management ##
- Version management
- Help file creation/publication (github pages?)
- Auto (cmdlet based) add functions/files to psd1/psm1 (internals ignore by naming convention?)
	- Assume ps1's are function files and add to psm1 to load?

## File Tools ##
- Clean files (expand alias, formatting type stuff)
- Run against PSAnalyzer?
- Function Builder (GUI based tool to build functions shells/params)

## Testing ##
- Help build tests? 
- Insert test folder with first basic test?

## Sign ##
- Automatically sign scripts upon release

## package ##
- Create a package (oneget/nuget/whatever)


## Release ##
- Publish as a release on github, choco, psgallery

# Next Steps #
1. Design workflow (what are the steps to build/publish)
2. Design cmdlets to address that workflow
3. Create Template Data
4. Build Tests
5. Build Functions