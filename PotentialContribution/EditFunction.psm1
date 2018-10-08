#requires -Version 3.0

# The EditFunction is going into the ModuleBuilder module...
## Version History:
# 4.0 - Added support for VS Code, fixed a bug in the internal SplitCommand
# 3.0 - made it work for file paths, and any script command. Added "edit" alias, and "NoWait" option.
# 2.1 - fixed the fix: always remove temp file, persist across-sessions in environment
# 2.0 - fixed persistence of editor options, made detection more clever
# 1.1 - refactored by June to (also) work on her machine (and have help)
# 1.0 - first draft, worked on my machine

function SplitCommand {
    <#
        .SYNOPSIS
            SplitCommand divides the input command into the executable command and the parameters
        .DESCRIPTION
            Start-Process needs the command name separate from the parameters

            The normal (unix) "Editor" environment variable (or the one in `git config core.editor`)
            can include parameters so it can be executed by just appending the file name.
    #>
    param(
        # The Editor command from the environment, like 'code -n -w'
        [Parameter(Mandatory=$true)]
        [string]$Command
    )
    $Parts = @($Command -Split " ")

    for ($count=0; $count -lt $Parts.Length; $count++) {
        $Editor = ($Parts[0..$count] -join " ").Trim("'",'"')
        if (Get-Command $Editor -ErrorAction Ignore) {
            $Editor
            $Parts[$($Count+1)..$($Parts.Length)] -join " "
            break
        }
    }
}

function Find-Editor {
    #.Synopsis
    #   Find a simple code editor
    #.Description
    #   Tries to find a text editor based on the PSEditor preference variable, the EDITOR environment variable, or your configuration for git.
    #   As a fallback it searches for Sublime, VSCode, Atom, or Notepad++, and finally falls back to Notepad.
    #
    #   I have deliberately excluded PowerShell_ISE because it is a single-instance app which doesn't support "wait" if it's already running.
    #   That is, if PowerShell_ISE is already running, issuing a command like this will return immediately:
    #
    #   Start-Process PowerShell_ISE $Profile -Wait
    [CmdletBinding()]
    param
    (
        # Specifies a code editor. If the editor is in the Path environment variable (Get-Command <editor>), you can enter just the editor name. Otherwise, enter the path to the executable file for the editor.
        # Defaults to the value of $PSEditor.Command or $PSEditor or Env:Editor if any of them are set.
        [Parameter(Position=1)]
        [System.String]
        $Editor = $(
            if($global:PSEditor.Command){
                $global:PSEditor.Command
            } else {
                $global:PSEditor
            }
        ),

        # Specifies commandline parameters for the editor.
        # Edit-Code.ps1 passes these editor-specific parameters to the editor you select.
        # For example, sublime uses -n -w to trigger a mode where closing the *tab* will return
        [Parameter(Position=2)]
        [System.String]
        $Parameters = $global:PSEditor.Parameters
    )

    end {
        do {# This is the GOTO hack: use break to skip to the end once we find it:
            # In this test, we let the Get-Command error leak out on purpose
            if($Editor -and (Get-Command $Editor)) { break }

            if ($Editor -and !(Get-Command $Editor -ErrorAction Ignore))
            {
                Write-Verbose "Editor is not a valid command, split it:"
                $Editor, $Parameters = SplitCommand $Editor
                if($Editor) { break }
            }

            if (Test-Path Env:Editor)
            {
                Write-Verbose "Editor was not passed in, trying Env:Editor"
                $Editor, $Parameters = SplitCommand $Env:Editor
                if($Editor) { break }
            }

            # If no editor is specified, try looking in git config
            if (Get-Command Git -ErrorAction Ignore)
            {
                Write-Verbose "PSEditor and Env:Editor not found, searching git config"
                if($CoreEditor = git config core.editor) {
                    $Editor, $Parameters = SplitCommand $CoreEditor
                    if($Editor) { break }
                }
            }

            # Try a few common ones that might be in the path
            Write-Verbose "Editor not found, trying some others"
            if($Editor = Get-Command "subl.exe", "sublime_text.exe" -ErrorAction Ignore| Select-Object -Expand Path -first 1)
            {
                $Parameters = "-n -w"
                break
            }
            if($Editor = Get-Command "code.cmd", "code-insiders" -ErrorAction Ignore | Select-Object -Expand Path -first 1)
            {
                $Parameters = "-n -w"
                break
            }
            if($Editor = Get-Command "atom.exe" -ErrorAction Ignore | Select-Object -Expand Path -first 1)
            {
                $Parameters = "-n -w"
                break
            }
            if($Editor = Get-Command "notepad++.exe" -ErrorAction Ignore | Select-Object -Expand Path -first 1)
            {
                $Parameters = "-multiInst"
                break
            }
            # Search the slow way for sublime
            Write-Verbose "Editor still not found, getting desperate:"
            if(($Editor = Get-Item "C:\Program Files\Sublime Text ?\sublime_text.exe" -ErrorAction Ignore | Sort {$_.VersionInfo.FileVersion} -Descending | Select-Object -First 1) -or
               ($Editor = Get-ChildItem C:\Program*\* -recurse -filter "sublime_text.exe" -ErrorAction Ignore | Select-Object -First 1))
            {
                $Parameters = "-n -w"
                break
            }

            if(($Editor = Get-ChildItem "C:\Program Files\Notepad++\notepad++.exe" -recurse -filter "notepad++.exe" -ErrorAction Ignore | Select-Object -First 1) -or
               ($Editor = Get-ChildItem C:\Program*\* -recurse -filter "notepad++.exe" -ErrorAction Ignore | Select-Object -First 1))
            {
                $Parameters = "-multiInst"
                break
            }

            # Settling for Notepad
            Write-Verbose "Editor not found, settling for notepad"
            $Editor = "notepad"

            if(!$Editor -or !(Get-Command $Editor -ErrorAction SilentlyContinue -ErrorVariable NotFound)) {
                if($NotFound) { $PSCmdlet.ThrowTerminatingError( $NotFound[0] ) }
                else {
                    throw "Could not find an editor (not even notepad!)"
                }
            }
        } while($false)

        $PSEditor = New-Object PSObject -Property @{
                Command = "$Editor"
                Parameters = "$Parameters"
        } | Add-Member ScriptMethod ToString -Value { "'" + $this.Command + "' " + $this.Parameters } -Force -PassThru

        # There are several reasons we might need to update the editor variable
        if($PSBoundParameters.ContainsKey("Editor") -or
           $PSBoundParameters.ContainsKey("Parameters") -or
           !(Test-Path variable:global:PSeditor) -or
           ($PSEditor.Command -ne $Editor))
        {
            # Store it pre-parsed and everything in the current session:
            Write-Verbose "Setting global preference variable for Editor: PSEditor"
            $global:PSEditor = $PSEditor

            # Store it stickily in the environment variable
            if(![Environment]::GetEnvironmentVariable("Editor", "User")) {
                Write-Verbose "Setting user environment variable: Editor"
                [Environment]::SetEnvironmentVariable("Editor", "$PSEditor", "User")
            }
        }
        return $PSEditor
    }
}

function Edit-Code {
    <#
        .SYNOPSIS
            Opens folders, files, or functions in your favorite code editor (configurable)

        .DESCRIPTION
            The Edit-Code command lets you open a folder, a file, or even a script function from your session in your favorite text editor.

            It opens the specified function in the editor that you specify, and when you finish editing the function and close the editor, the script updates the function in your session with the new function code.

            Functions are tricky to edit, because most code editors require a file, and determine syntax highlighting based on the extension of that file. Edit-Code creates a temporary file with the function code.

            If you have a favorite editor, you can use the Editor parameter to specify it once, and the script will save it as your preference. If you don't specify an editor, it tries to determine an editor using the PSEditor preference variable, the EDITOR environment variable, or your configuration for git.  As a fallback it searches for Sublime, and finally falls back to Notepad.

            REMEMBER: Because functions are specific to a session, your function edits are lost when you close the session unless you save them in a permanent file, such as your Windows PowerShell profile.

        .EXAMPLE
            Edit-Code Prompt

            Opens the prompt function in a default editor (gitpad, Sublime, Notepad, whatever)

        .EXAMPLE
            dir Function:\cd* | Edit-Code -Editor "C:\Program Files\Sublime Text 3\subl.exe" -Param "-n -w"

            Pipes all functions starting with cd to Edit-Code, which opens them one at a time in a new sublime window (opens each one after the other closes).

        .EXAMPLE
            Get-Command TabExpan* | Edit-Code -Editor 'C:\Program Files\SAPIEN Technologies, Inc\PowerShell Studio 2014\PowerShell Studio.exe

            Edits the TabExpansion and/or TabExpansion2 (whichever exists) in PowerShell Studio 2014 using the full path to the .exe file.
            Note that this also sets PowerShell Studio as your default editor for future calls.

        .NOTES
            By Joel Bennett (@Jaykul) and June Blender (@juneb_get_help)

            If you'd like anything changed  ... feel free to push new version on PoshCode, or tweet at me :-)
            - Do you not like that I make every editor the default?
            - Think I should detect notepad2 or notepad++ or something?

            About ISE: it doesn't support waiting for the editor to close, sorry.
            If you're sure you don't care about that, and want to use PowerShell ISE, you can set it in $PSEditor or pass it as a parameter.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess","")]
    [Alias("edit")]
    [CmdletBinding(DefaultParameterSetName="Command")]
    param (
        # Specifies the name of a function or script to create or edit. Enter a function name or pipe a function to Edit-Code.
        # This parameter is required. If the function doesn't exist in the session, Edit-Code creates it.
        [Parameter(Position=0, Mandatory = $true, ValueFromPipelineByPropertyName = $true, ParameterSetName="Command")]
        [Alias("PSPath")]
        [String]
        $Command,

        # Specifies the name of a function or script to create or edit. Enter a function name or pipe a function to Edit-Code.ps1.
        # This parameter is required. If the function doesn't exist in the session, Edit-Code creates it.
        [Parameter(Mandatory = $true, ParameterSetName="File", ValueFromPipelineByPropertyName = $true)]
        [String[]]
        $Path,

        # Specifies a code editor.
        # If the editor is in the Path environment variable (Get-Command <editor>), you can enter just the editor name.
        # Otherwise, enter the path to the executable file for the editor.
        # Defaults to the value of $PSEditor.Command or $PSEditor or Env:Editor if any of them are set.
        [Parameter(Position=1)]
        [String]
        $Editor = $(
            if ($global:PSEditor.Command) {
                $global:PSEditor.Command
            } else {
                $global:PSEditor
            }
        ),

        # Specifies commandline parameters for the editor.
        # Edit-Code.ps1 passes these editor-specific parameters to the editor you select.
        # For example, sublime uses -n -w to trigger a mode where closing the *tab* will return
        [Parameter(Position=2)]
        [String]
        $Parameters = $global:PSEditor.Parameters,

        # Skips waiting for the editor.
        # If this switch is set, editing functions won't work, as the function won't be updated after you finish editing the file. However, you will still be able to save the function contents as a script to disk (and manually remove the function definition).
        # Perfect for when you just want to open a pre-existing text file in your editor and leave it there while you continue working in the console.
        [Switch]$Wait,

        # Force editing "Application" scripts.
        # Files with extensions .cmd, .bat, .vbs, .pl, .rb, .py, .wsf, and .js are known to editable, others will prompt unless Force is set, because most "Application"s aren't editable (they're .exe, .cpl, .com, .msc, etc.)
        [Switch]$Force
    )
    begin {
        # This is probably a terrible idea ...
        $TextApplications  = ".cmd",".bat",".vbs",".pl",".rb",".py",".wsf",".js",".ps1"
        $NonFileCharacters = "[$(([IO.Path]::GetInvalidFileNameChars() | %{ [regex]::escape($_) }) -join '|')]"

        $RejectAll = $false;
        $ConfirmAll = $false;
    }
    process {
        [String[]]$Files = @()
        # Resolve-Alias-A-la-cheap:
        $MaxDepth = 10
        if($PSCmdlet.ParameterSetName -eq "Command") {
            while($Cmd = Get-Command $Command -Type Alias -ErrorAction Ignore) {
                $Command = $Cmd.definition
                if(($MaxDepth--) -lt 0) { break }
            }

            # We know how to edit Functions, ExternalScript, and even Applications, if you're sure...
            $Files = @(
                switch(Get-Command $Command -ErrorAction "Ignore" -Type "Function", "ExternalScript", "Application" | Select-Object -First 1) {
                    { $_.CommandType -eq "Function"}{
                        Write-Verbose "Found a function matching $Command"
                        #Creates a temporary file in your temp directory with a .tmp.ps1 extension.
                        $File = [IO.Path]::GetTempFileName() |
                            Rename-Item -NewName { [IO.Path]::ChangeExtension($_, ".tmp.ps1") } -PassThru |
                            Select-Object -Expand FullName

                        #If you have a function with this name, it saves the function code in the temporary file.
                        if (Test-Path Function:\$Command) {
                            Set-Content -Path $File -Value $((Get-Content Function:\$Command) -Join "`n")
                        }
                        $File
                    }

                    {$_.CommandType -eq "ExternalScript"}{
                        Write-Verbose "Found an ExternalScript matching $Command"
                        $_.Path
                    }

                    {$_.CommandType -eq "Application"} {
                        Write-Verbose "Found an Application or Script matching $Command"
                        if(($TextApplications -contains $_.Extension) -or $Force -Or $PSCmdlet.ShouldContinue("Are you sure you want to edit '$($_.Path)' in a text editor?", "Opening '$($_.Name)'", [ref]$ConfirmAll, [ref]$RejectAll)) {
                            $_.Path
                        }
                    }
                }
            )

            if($Files.Length -eq 0) {
                Write-Verbose "No '$Command' command found, resolving file path"
                $Files = @(Resolve-Path $Command -ErrorAction Ignore | Select-Object -Expand Path)

                if($Files.Length -eq 0) {
                    Write-Verbose "Still no file found, they're probably trying to create a new function"
                    # If the function name is basically ok, then lets make an random empty file for them to write it
                    if($Command -notmatch $NonFileCharacters) {
                        # Creates a temporary file in your temp directory with a .tmp.ps1 extension.
                        $File = [IO.Path]::GetTempFileName() |
                            Rename-Item -NewName { [IO.Path]::ChangeExtension($_, ".tmp.ps1") } -PassThru |
                            Select-Object -Expand FullName

                        #If you have a function with this name, it saves the function code in the temporary file.
                        if (Test-Path Function:\$Command) {
                            Set-Content -Path $file -Value $((Get-Content Function:\$Command) -Join "`n")
                        }
                        $Files = @($File)
                    }
                } else {
                    $Files
                }
            }
        } else {
            Write-Verbose "Resolving file path, because although we'll create files, we won't create directories"
            $Folder = Split-Path $Path
            $FileName = Split-Path $Path -Leaf
            # If the folder doesn't exist, die
            $Files = @(
                if($Folder -and -not (Resolve-Path $Folder -ErrorAction Ignore)) {
                    Write-Error "The path '$Folder' doesn't exist, so we cannot create '$FileName' there"
                    return
                } elseif($FileName -notmatch $NonFileCharacters) {
                    foreach($F in Resolve-Path $Folder -ErrorAction Ignore) {
                        Join-Path $F $FileName
                    }
                } else {
                    Resolve-Path $Path -ErrorAction Ignore | Select-Object -Expand Path
                }
            )
        }

        $PSEditor = Find-Editor

        # Finally, edit the file!
        foreach($File in @($Files)) {
            if($File) {
                $LastWriteTime = (Get-Item $File).LastWriteTime

                # If it's a temp file, they're editing a function, so we have to wait!
                if($File.EndsWith(".tmp.ps1") -and $File.StartsWith(([IO.Path]::GetTempPath()))) {
                    $Wait = $true
                }

                # Avoid errors if Parameter is null/empty.
                Write-Verbose "$PSEditor '$File'"
                if ($PSEditor.Parameters)
                {
                    Start-Process -FilePath $PSEditor.Command -ArgumentList $PSEditor.Parameters, """$file""" -Wait:($Wait) -NoNewWindow
                }
                else
                {
                    Start-Process -FilePath $PSEditor.Command -ArgumentList """$file""" -Wait:($Wait) -NoNewWindow
                }

                # Remove it if we created it
                if($File.EndsWith(".tmp.ps1") -and $File.StartsWith(([IO.Path]::GetTempPath()))) {

                    if($LastWriteTime -ne (Get-Item $File).LastWriteTime) {
                        Write-Verbose "Changed $Command function"
                        # Recreates the function from the code in the temporary file and then deletes the file.
                        Set-Content -Path Function:\$Command -Value ([scriptblock]::create(((Get-Content $file) -Join "`n")))
                    } else {
                        Write-Warning "No change to $Command function"
                    }

                    Write-Verbose "Deleting temp file $File"
                    Remove-Item $File
                }
            }
        }
    }
}

Export-ModuleMember -Function Edit-Code, Find-Editor -Alias edit