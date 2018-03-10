#Requires -version 2.0

## Authenticode.psm1 updated for PowerShell 2.0 (with time stamping)
####################################################################################################
## Wrappers for the Get-AuthenticodeSignature and Set-AuthenticodeSignature cmdlets 
## These properly parse paths, so they don't kill your pipeline and script if you include a folder 
##
## Usage:
## ls | Get-AuthenticodeSignature
##    Get all the signatures
##
## ls | Select-AuthenticodeSigned -Mine -Broken | Set-AuthenticodeSignature
##    Re-sign anything you signed before that has changed
##
## ls | Select-AuthenticodeSigned -NotMine -ValidOnly | Set-AuthenticodeSignature
##    Re-sign scripts that are hash-correct but not signed by me or by someone trusted
##
####################################################################################################
## History:
## 2.5 - Added support for storing a different default cert per computer in the psd1
##       Now I can sync from work to home, and still use the right cert in each place.
## 2.4 - Added a -Module parameter to the Set-AuthenticodeSignature 
##       It will recursively sign all the signable files in a module...
##     - Tweaked Get-AuthenticodeCertificate to first search Cert:\CurrentUser\My 
##       's much faster on my home PC this way
## 2.3 - Reworked Get-UserCertificate and Get-AuthenticodeCertificate for better behavior
## 2.2 - Added sorting and filtering the displayed certs, and the option to save your choice
## 2.1 - Added some extra exports and aliases, and included my Start-AutoSign script...
## 2.0 - Updated to work with PowerShell 2.0 RTM and add -TimeStampUrl support
## 1.7 - Modified the reading of certs to better support people who only have one :)
## 1.6 - Converted to work with CTP 3, and added function help comments
## 1.5 - Moved the default certificate setting into the module info Authenticode.psd1 file
##       Note: If you get this off PoshCode, you'll have to create it yourself, see below:
## 1.4 - Moved the default certificate setting into an external psd1 file.
## 1.3 - Fixed some bugs in If-Signed and renamed it to Select-AuthenticodeSigned
##     - Added -MineOnly and -NotMineOnly switches to Select-AuthenticodeSigned
## 1.2 - Added a hack workaround to make it appear as though we can sign and check PSM1 files
##       It's important to remember that the signatures are NOT checked by PowerShell yet...
## 1.1 - Added a filter "If-Signed" that can be used like: ls | If-Signed
##     - With optional switches: ValidOnly, InvalidOnly, BrokenOnly, TrustedOnly, UnsignedOnly
##     - commented out the default Certificate which won't work for "you"
## 1.0 - first working version, includes wrappers for Get and Set
##
####################################################################################################


function ConvertTo-StringData { param([Parameter(ValueFromPipeline=$true)]$InputObject)
   switch($InputObject.GetType().FullName) {
      'System.Collections.Hashtable' { ($InputObject.Keys | % { "$_=$($InputObject.$_)" }) -join "`n" }
}  }

function Get-UserCertificate {
   <#
      .SYNOPSIS
       Gets the user's default signing certificate so we don't have to ask them over and over...
      .DESCRIPTION
       The Get-UserCertificate function retrieves and returns a certificate from the user. It also stores the certificate so it can be reused without re-querying for the location and/or password ... 
      .RETURNVALUE
       An X509Certificate2 suitable for code-signing
   #>
   [CmdletBinding()]
   param ( $Name )
   begin {
      if($Name) { 
         $Script:UserCertificate = Get-AuthenticodeCertificate $Name
      }
   }
   end {
      $PrivateData = ConvertFrom-StringData (Test-ModuleManifest "$PSScriptRoot\Authenticode.psd1").PrivateData
      if(!$PrivateData) { $PrivateData = @{} }
      
      ## If they don't have a cert, or they haven't stored it...
      if(!(Test-Path Variable:Script:UserCertificate) -or 
         $Script:UserCertificate -isnot [System.Security.Cryptography.X509Certificates.X509Certificate2] -or
         $Script:UserCertificate.Thumbprint -ne $PrivateData.${Env:ComputerName}
      ) {
         ## Verbose output
         if($VerbosePreference -gt "SilentlyContinue") {
            if(!(Test-Path Variable:Script:UserCertificate)) {
               Write-Verbose "Loading User Certificate from Module Config: $($PrivateData.${Env:ComputerName} )"
            } else {
               Write-Verbose "Saving User Certificate to Module Config: ($($Script:UserCertificate.Thumbprint) -ne $($PrivateData.${Env:ComputerName}))"
            }
         }
         
         Write-Debug "PrivateData: $($ExecutionContext.SessionState.Module | fl * | Out-String)"
         ## If they don't have a cert
         if(!(Test-Path Variable:Script:UserCertificate) -or $Script:UserCertificate -isnot [System.Security.Cryptography.X509Certificates.X509Certificate2]) {
            $Script:UserCertificate = Get-AuthenticodeCertificate $PrivateData.${Env:ComputerName}
         }
         Write-Verbose "Confirming Certificate: $($Script:UserCertificate.Thumbprint)"
         
         ## If their cert isn't stored at least temporarily...
         if($Script:UserCertificate -and (!$PrivateData.${Env:ComputerName} -or
                                         ($PrivateData.${Env:ComputerName} -ne $Script:UserCertificate.Thumbprint)))
         {
            ## Store it temporarily ...
            $PrivateData.${Env:ComputerName} = $Script:UserCertificate.Thumbprint
            
            ## And ask them if they want to store it permanently
            Write-Verbose "Updating Module Metadata"
            if($Host.UI -and $Host.UI.PromptForChoice -and (0 -eq
               $Host.UI.PromptForChoice("Keep this certificate for future sessions?", $Script:UserCertificate,
               [Management.Automation.Host.ChoiceDescription[]]@("&Yes","&No"), 0))
            ) {
               $mVersion = (Test-ModuleManifest "$PSScriptRoot\Authenticode.psd1").Version
               
               Write-Verbose "Version: $mVersion"
               if($MVersion -le "2.5") { $MVersion = 2.5 }
               
               New-ModuleManifest $PSScriptRoot\Authenticode.psd1                         `
                          -ModuleToProcess Authenticode.psm1                `
                          -Author 'Joel Bennett' -Company 'HuddledMasses.org'             `
                          -ModuleVersion  $MVersion                                       `
                          -PowerShellVersion '2.0'                                        `
                          -Copyright '(c) 2008-2010, Joel Bennett'                        `
                          -Desc 'Function wrappers for Authenticode Signing cmdlets'      `
                          -Types @() -Formats @() -RequiredModules @()                    `
                          -RequiredAssemblies @() -FileList @("Authenticode.psm1","Authenticode.psd1") -NestedModules @()        `
                          -PrivateData ($PrivateData | ConvertTo-StringData)
               $null = Sign $PSScriptRoot\Authenticode.psd1 -Cert $Script:UserCertificate
            }
         }
      }
      return $Script:UserCertificate
   }
}

function Get-AuthenticodeCertificate {
   [CmdletBinding()]
   param (
      $Name = $(Get-UserCertificate)
   )

   end {
      $Certificate = $Name
      # Until they get a cert, or hit ENTER without any input
      while($Certificate -isnot [System.Security.Cryptography.X509Certificates.X509Certificate2]) {
         trap {
            Write-Host "The authenticode module requires a code-signing certificate, and can't find yours!"
            Write-Host
            Write-Host "If this is the first time you've seen this error, please run Get-AuthenticodeCertificate by hand and specify the full path to your PFX file, or the Thumbprint of a cert in your OS Cert store -- and then answer YES to save that cert in the 'PrivateData' of the Authenticode Module metadata."
            Write-Host
            Write-Host "If you have seen this error multiple times, you may need to manually create a module manifest for this module with the path to your cert, and/or specify the certificate name each time you use it."
            Write-Error $_
            continue      
         }
         ## If they haven't specified the name, prompt them:
         if(!$Name) {
            push-Location Cert:\
            $certs = @(Get-ChildItem -Recurse -CodeSigningCert | Sort NotAfter)
            pop-Location
            if($certs.Count) {
               Write-Host "You have $($certs.Count) code signing certificates in your local certificate storage which you can specify by partial Thumbprint, or you may specify the path to a .pfx file:" -fore cyan
               $certs | Out-Host
            }
            $Name = $(Read-Host "Please specify a user certificate (wildcards allowed)")
            if(!$Name) { return }
         }
         
         Write-Verbose "Certificate Path: $Name"
         ## Check "CurrentUsers\My" first, because it's MOST LIKELY there, and it will be MUCH faster in some cases.
         $ResolvedPath = Get-ChildItem Cert:\CurrentUser\My -Recurse -CodeSigningCert | Where {$_.ThumbPrint -like $Name } | Select -Expand PSPath
         if(!$ResolvedPath) {
            ## We have to at least check the other folders too, if we didn't find it.
            $ResolvedPath = Get-ChildItem Cert:\ -Recurse -CodeSigningCert | Where {$_.ThumbPrint -like $Name } | Select -Expand PSPath
         }
         
         if(!$ResolvedPath) {
            Write-Verbose "Not a Certificate path: $Path"
            $ResolvedPath = Resolve-Path $Name -ErrorAction "SilentlyContinue" | Where { Test-Path $_ -PathType Leaf -ErrorAction "SilentlyContinue" }
         }
         
         if(!$ResolvedPath) {
            Write-Verbose "Not a full or legit relative path Path: $ResolvedPath"
            $ResolvedPath = Resolve-Path (Join-Path $PsScriptRoot $Name -ErrorAction "SilentlyContinue") -ErrorAction "SilentlyContinue" | Where { Test-Path $_ -PathType Leaf -ErrorAction "SilentlyContinue" }
            Write-Verbose "Resolved File Path: $ResolvedPath"
         }
         
         if(@($ResolvedPath).Count -gt 1) {
            throw "You need to specify enough of the name to narrow it to a single certificate. '$Name' returned $(@($ResolvedPath).Count):`n$($ResolvedPath|Out-String)"
         }

         $Certificate = get-item $ResolvedPath -ErrorAction "SilentlyContinue"
         if($Certificate -is [System.IO.FileInfo]) {
            $Certificate = Get-PfxCertificate $Certificate -ErrorAction "SilentlyContinue"
         }
         $Name = $Null # Blank it out so we re-prompt them
      }
      Write-Verbose "Certificate: $($Certificate | Out-String)"
      return $Certificate
   }
}

function Test-AuthenticodeSignature {
   <#
      .SYNOPSIS
         Tests a script signature to see if it is valid, or at least unaltered.
      .DESCRIPTION
         The Test-AuthenticodeSignature function processes the output of Get-AuthenticodeSignature to determine if it 
         is Valid, OR **unaltered** and signed by the user's certificate
      .PARAMETER Signature
         Specifies the signature object to test. This should be the output of Get-AuthenticodeSignature.
      .PARAMETER ForceValid
         Switch parameter, forces the signature to be valid -- otherwise, even if the certificate chain can't be verified, we will accept the cert which matches the "user" certificate (see Get-UserCertificate).
         Aliases                      Valid
      .EXAMPLE
         ls *.ps1 | Get-AuthenticodeSignature | Where {Test-AuthenticodeSignature $_}
         To get the signature reports for all the scripts that we consider safely signed.
      .EXAMPLE
         ls | ? { gas $_ | Test-AuthenticodeSignature }
         List all the valid signed scripts (or scripts signed by our cert)
      .NOTES
         Test-AuthenticodeSignature returns TRUE even if the root CA certificate can't be verified, as long as the signing certificate's thumbnail matches the one specified by Get-UserCertificate.
      .INPUTTYPE
         System.Management.Automation.Signature
      .RETURNVALUE
         Boolean value representing whether the script's signature is valid, or YOUR certificate
   #>
   [CmdletBinding()]
   param (
      [Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
      $Signature
   ,
      [Alias("Valid")]
      [Switch]$ForceValid
   )

   return ( $Signature.Status -eq "Valid" -or 
         ( !$ForceValid -and 
            ($Signature.Status -eq "UnknownError") -and 
            ($_.SignerCertificate.Thumbprint -eq $(Get-UserCertificate).Thumbprint) 
         ) )
}

####################################################################################################
function Set-AuthenticodeSignature {
   <#
      .SYNOPSIS
         Adds an Authenticode signature to a Windows PowerShell script or other file.
      .DESCRIPTION
         The Set-AuthenticodeSignature function adds an Authenticode signature to any file that supports Subject Interface Package (SIP).
       
         In a Windows PowerShell script file, the signature takes the form of a block of text that indicates the end of the instructions that are executed in the script. If there is a signature  in the file when this cmdlet runs, that signature is removed.
      .NOTES
         After the certificate has been validated, but before a signature is added to the file, the function checks the value of the $SigningApproved preference variable. If this variable is not set, or has a value other than TRUE, you are prompted to confirm the signing of the script.
       
         When specifying multiple values for a parameter, use commas to separate the values. For example, "<parameter-name> <value1>, <value2>".
      .EXAMPLE
         ls *.ps1 | Set-AuthenticodeSignature -Certificate $Certificate
         
         To sign all of the files with the specified certificate
      .EXAMPLE
         ls *.ps1,*.psm1,*.psd1 | Get-AuthenticodeSignature | Where {!(Test-AuthenticodeSignature $_ -Valid)} | gci | Set-AuthenticodeSignature

         List all the script files, and get and test their signatures, and then sign all of the ones that are not valid, using the user's default certificate.
      .EXAMPLE
         Set-AuthenticodeSignature -Module PSCX
         
         Signs the whole PSCX module at once (all the ps1, psm1, psd1, dll, exe, and ps1xml files, etc.).
      .INPUTTYPE
         String. You can pipe a file path to Set-AuthenticodeSignature.
      .PARAMETER FilePath
         Specifies the path to a file that is being signed.
         Aliases                      Path, FullName
      .PARAMETER ModuleName
         Specifies a module name (or path) to sign. 
         
         When you specify a module name, all of the files in that folder and it's subfolders are signed (if they're signable).   
      .PARAMETER Certificate
         Specifies the certificate that will be used to sign the script or file. Enter a variable that stores an object representing the certificate or an expression that gets the certificate.
        
         To find a certificate, use Get-PfxCertificate or use the Get-ChildItem cmdlet in the Certificate (Cert:) drive. If the certificate is not valid or does not have code-signing authority, the command fails.
      .PARAMETER Force
         Allows the cmdlet to append a signature to a read-only file. Even using the Force parameter, the cmdlet cannot override security restrictions.
      .Parameter HashAlgorithm
         Specifies the hashing algorithm that Windows uses to compute the digital signature for the file. The default is SHA1, which is the Windows default hashing algorithm.

         Files that are signed with a different hashing algorithm might not be recognized on other systems.
      .PARAMETER IncludeChain
         Determines which certificates in the certificate trust chain are included in the digital signature. "NotRoot" is the default.

         Valid values are:

         -- Signer: Includes only the signer's certificate.

         -- NotRoot: Includes all of the certificates in the certificate chain, except for the root authority.

         -- All: Includes all the certificates in the certificate chain.

      .PARAMETER TimestampServer
         Uses the specified time stamp server to add a time stamp to the signature. Type the URL of the time stamp server as a string.
         Defaults to Verisign's server: http://timestamp.verisign.com/scripts/timstamp.dll

         The time stamp represents the exact time that the certificate was added to the file. A time stamp prevents the script from failing if the certificate expires because users and programs can verify that the certificate was valid atthe time of signing.
      .RETURNVALUE
         System.Management.Automation.Signature
   #>
   [CmdletBinding(DefaultParameterSetName="File")]
   param ( 
      [Parameter(Position=1, Mandatory=$true, ValueFromPipelineByPropertyName=$true, ParameterSetName="File")]
      [Alias("FullName")]
      [ValidateScript({ 
         if((resolve-path $_).Provider.Name -ne "FileSystem") {
            throw "Specified Path is not in the FileSystem: '$_'" 
         }
         return $true
      })]
      [string[]]$FilePath
   ,
      [Parameter(Position=1, Mandatory=$true, ValueFromPipelineByPropertyName=$true, ParameterSetName="Module")]
      [Alias("ModuleName")]
      [string[]]$ModuleBase
   ## In many cases, you CANNOT safely call Get-Module -List, so let's not do it in the Validation.
   #  [ValidateScript({ 
   #     if(!(Get-Module -List $_)) {
   #        $short = $_ | Split-Path -Leaf
   #        if(!(Get-Module -List $short)) {
   #           throw "Cannot find a module by that name: '$_'"
   #        }
   #     }
   #     return $true
   #  })]
   , 
      [Parameter(Position=2, Mandatory=$false)]
      $Certificate
   , 
      [Switch]$Force
   ,
      [ValidateSet("SHA","MD5","SHA1","SHA256","SHA384","SHA512")]
      [String]$HashAlgorithm #="SHA1"
   ,
      [ValidateSet("Signer","NotRoot","All")]
      [String]$IncludeChain #="NotRoot"
   ,
      [String]$TimestampServer = "http://timestamp.verisign.com/scripts/timstamp.dll"
   )
   begin {
      Write-Verbose $("ParameterSetName 1: " + $PSCmdlet.ParameterSetName)
      ## Can't specify this as a default value if we're in the pipeline, it doesn't get bound in time?
      if(!$Certificate) {
         $Certificate = Get-UserCertificate
      }
      if($Certificate -isnot [System.Security.Cryptography.X509Certificates.X509Certificate2]) {
         $Certificate = Get-AuthenticodeCertificate $Certificate
      }
      $PSBoundParameters["Certificate"] = $Certificate
      $PSBoundParameters["TimestampServer"] = $TimestampServer
   }
   process {
      Write-Verbose $("ParameterSetName 2: " + $PSCmdlet.ParameterSetName)

      if($PSCmdlet.ParameterSetName -eq "Module"){
         $ModuleBase = $ModuleBase | Split-Path -Leaf
         Write-Verbose "Signing Modules: $($ModuleBase -join ', ')"
         $FilePath = Get-Module -List $ModuleBase | Split-Path |
                        Get-ChildItem -Recurse |
                        Where-Object { !$_.PsIsContainer -and  (".ps1",".psm1",".psd1",".ps1xml",".dll",".exe" -contains $_.Extension) } | 
                        Select-Object -Expand FullName

         $null = $PSBoundParameters.Remove("ModuleBase")
         Write-Verbose "Signing Files: $($FilePath | Out-String)"
      }
      
      Write-Verbose $("ParameterSetName 4: " + $PSCmdlet.ParameterSetName)
      foreach($file in @($FilePath)) {
         trap { Write-Warning "Could not sign file '$File' `n`n because $_"; continue }
         $PSBoundParameters.FilePath = $file
         if(Test-Path $file -Type Leaf) {
            Write-Verbose "Set Authenticode Signature on $FilePath with $($Certificate | Out-String)"
            $null = $PSBoundParameters.Remove("ModuleBase")
            Microsoft.PowerShell.Security\Set-AuthenticodeSignature @PSBoundParameters
         } else {
            Write-Warning "Cannot sign folders: '$file'" 
         }
      }
      return
   }
}

####################################################################################################
function Get-AuthenticodeSignature {
<#.SYNOPSIS

   Gets information about the Authenticode signature in a file.
.DESCRIPTION
   The Get-AuthenticodeSignature function gets information about the Authenticode signature in a file. If the file is not signed, the information is retrieved, but the fields are blank.
.NOTES
   For information about Authenticode signatures in Windows PowerShell, type "get-help About_Signing".

   When specifying multiple values for a parameter, use commas to separate the values. For example, "-<parameter-name> <value1>, <value2>".
.EXAMPLE
   Get-AuthenticodeSignature script.ps1
   
   To get the signature information about the script.ps1 script file.
.EXAMPLE
   ls *.ps1,*.psm1,*.psd1 | Get-AuthenticodeSignature
   
   Get the signature information for all the script and data files
.EXAMPLE
   ls *.ps1,*.psm1,*.psd1 | Get-AuthenticodeSignature | Where {!(Test-AuthenticodeSignature $_ -Valid)} | gci | Set-AuthenticodeSignature

   This command gets information about the Authenticode signature in all of the script and module files, and tests the signatures, then signs all of the ones that are not valid.
.INPUTTYPE
   String. You can pipe the path to a file to Get-AuthenticodeSignature.
.PARAMETER FilePath
   The path to the file being examined. Wildcards are permitted, but they must lead to a single file. The parameter name ("-FilePath") is optional.
   Aliases                      Path, FullName
.RETURNVALUE
   System.Management.Automation.Signature
###################################################################################################>
[CmdletBinding()]
param ( 
   [Parameter(Position=1, Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
   [Alias("FullName","Path")]
   [ValidateScript({ 
      if((resolve-path $_).Provider.Name -ne "FileSystem") {
         throw "Specified Path is not in the FileSystem: '$_'" 
      }
      if(!(Test-Path -PathType Leaf $_)) { 
         throw "Specified Path is not a File: '$_'" 
      }
      return $true
   })]
   [string[]]
   $FilePath
)

process {
   Microsoft.PowerShell.Security\Get-AuthenticodeSignature -FilePath $FilePath
}
}

####################################################################################################
function Select-AuthenticodeSigned {
<#.SYNOPSIS
   Select files based on the status of their Authenticode Signature.
.DESCRIPTION
   The Select-AuthenticodeSigned function filters files on the pipeline based on the state of their authenticode signature.
.NOTES
   For information about Authenticode signatures in Windows PowerShell, type "get-help About_Signing".

   When specifying multiple values for a parameter, use commas to separate the values. For example, "-<parameter-name> <value1>, <value2>".
.EXAMPLE
   ls *.ps1,*.ps[dm]1 | Select-AuthenticodeSigned
   
   To get the signature information about the script.ps1 script file.
.EXAMPLE
   ls *.ps1,*.psm1,*.psd1 | Get-AuthenticodeSignature
   
   Get the signature information for all the script and data files
.EXAMPLE
   ls *.ps1,*.psm1,*.psd1 | Get-AuthenticodeSignature | Where {!(Test-AuthenticodeSignature $_ -Valid)} | gci | Set-AuthenticodeSignature

   This command gets information about the Authenticode signature in all of the script and module files, and tests the signatures, then signs all of the ones that are not valid.
.INPUTTYPE
   String. You can pipe the path to a file to Get-AuthenticodeSignature.
.PARAMETER FilePath
   The path to the file being examined. Wildcards are permitted, but they must lead to a single file. The parameter name ("-FilePath") is optional.
   Aliases                      Path, FullName
.RETURNVALUE
   System.Management.Automation.Signature
###################################################################################################>
[CmdletBinding()]
param ( 
   [Parameter(Position=1, Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
   [Alias("FullName")]
   [ValidateScript({ 
      if((resolve-path $_).Provider.Name -ne "FileSystem") {
         throw "Specified Path is not in the FileSystem: '$_'" 
      }
      return $true
   })]
   [string[]]
   $FilePath
,
   [Parameter()]
   # Return only files that are signed with the users' certificate (as returned by Get-UserCertificate).
   [switch]$MineOnly
,
   [Parameter()]
   # Return only files that are NOT signed with the users' certificate (as returned by Get-UserCertificate).
   [switch]$NotMineOnly
,
   [Parameter()]
   [Alias("HashMismatch")]
   # Return only files with signatures that are broken (where the file has been edited, and the hash doesn't match).
   [switch]$BrokenOnly
,
   [Parameter()]
   # Returns the files that are Valid OR signed with the users' certificate (as returned by Get-UserCertificate).
   #
   # That is, TrustedOnly returns files returned by -ValidOnly OR -MineOnly (if you specify both parameters, you get only files that are BOTH -ValidOnly AND -MineOnly)
   [switch]$TrustedOnly
,
   [Parameter()]
   # Return only files that are "Valid": This means signed with any cert where the certificate chain is verifiable to a trusted root certificate.  This may or may not include files signed with the user's certificate.
   [switch]$ValidOnly
,
   [Parameter()]
   # Return only files that doesn't have a "Valid" signature, which includes files that aren't signed, or that have a hash mismatch, or are signed by untrusted certs (possibly including the user's certificate).
   [switch]$InvalidOnly
,
   [Parameter()]
   # Return only signable files that aren't signed at all. That is, only files that support Subject Interface Package (SIP) but aren't signed.
   [switch]$UnsignedOnly

)
process {
   if(!(Test-Path -PathType Leaf $FilePath)) { 
      # if($ErrorAction -ne "SilentlyContinue") {
      #    Write-Error "Specified Path is not a File: '$FilePath'"
      # }
   } else {

      foreach($sig in Get-AuthenticodeSignature -FilePath $FilePath) {
      
      # Broken only returns ONLY things which are HashMismatch
      if($BrokenOnly   -and $sig.Status -ne "HashMismatch") 
      { 
         Write-Debug "$($sig.Status) - Not Broken: $FilePath"
         return 
      }
      
      # Trusted only returns ONLY things which are Valid
      if($ValidOnly    -and $sig.Status -ne "Valid") 
      { 
         Write-Debug "$($sig.Status) - Not Trusted: $FilePath"
         return 
      }
      
      # AllValid returns only things that are SIGNED and not HashMismatch
      if($TrustedOnly  -and (($sig.Status -ne "HashMismatch") -or !$sig.SignerCertificate) ) 
      { 
         Write-Debug "$($sig.Status) - Not Valid: $FilePath"
         return 
      }
      
      # InvalidOnly returns things that are Either NotSigned OR HashMismatch ...
      if($InvalidOnly  -and ($sig.Status -eq "Valid")) 
      { 
         Write-Debug "$($sig.Status) - Valid: $FilePath"
         return 
      }
      
      # Unsigned returns only things that aren't signed
      # NOTE: we don't test using NotSigned, because that's only set for .ps1 or .exe files??
      if($UnsignedOnly -and $sig.SignerCertificate ) 
      { 
         Write-Debug "$($sig.Status) - Signed: $FilePath"
         return 
      }
      
      # Mine returns only things that were signed by MY CertificateThumbprint
      if($MineOnly     -and (!($sig.SignerCertificate) -or ($sig.SignerCertificate.Thumbprint -ne $((Get-UserCertificate).Thumbprint))))
      {
         Write-Debug "Originally signed by someone else, thumbprint: $($sig.SignerCertificate.Thumbprint)"
         Write-Debug "Does not match your default certificate print: $((Get-UserCertificate).Thumbprint)"
         Write-Debug "     $FilePath"
         return 
      }

      # NotMine returns only things that were NOT signed by MY CertificateThumbprint
      if($NotMineOnly  -and (!($sig.SignerCertificate) -or ($sig.SignerCertificate.Thumbprint -eq $((Get-UserCertificate).Thumbprint))))
      {
         if($sig.SignerCertificate) {
            Write-Debug "Originally signed by you, thumbprint: $($sig.SignerCertificate.Thumbprint)"
            Write-Debug "Matches your default certificate print: $((Get-UserCertificate).Thumbprint)"
            Write-Debug "     $FilePath"
         }
         return 
      }
      
      if(!$BrokenOnly  -and !$TrustedOnly -and !$ValidOnly -and !$InvalidOnly -and !$UnsignedOnly -and !($sig.SignerCertificate) ) 
      { 
         Write-Debug "$($sig.Status) - Not Signed: $FilePath"
         return 
      }
      
      get-childItem $sig.Path
   }}
}
}


function Start-AutoSign {
# .Synopsis
#     Start a FileSystemWatcher to automatically sign scripts when you save them
# .Description
#     Create a FileSystemWatcher with a scriptblock that uses the Authenticode script Module to sign anything that changes
# .Parameter Path
#     The path to the folder you want to monitor
# .Parameter Filter
#     A filter to select only certain files: by default, *.ps*  (because we can only sign .ps1, .psm1, .psd1, and .ps1xml 
# .Parameter Recurse
#     Whether we should also watch autosign files in subdirectories
# .Parameter CertPath
#     The path or name of a certain certificate, to override the defaults from the Authenticode Module
# .Parameter NoNotify
#     Whether wo should avoid using Growl to notify the user each time we sign something.
# .NOTE 
#     Don't run this on a location where you're going to be generating dozens or hundreds of files ;)
param($Path=".", $Filter= "*.ps*", [Switch]$Recurse, $CertPath, [Switch]$NoNotify)

if(!$NoNotify -and (Get-Module Growl -ListAvailable -ErrorAction 0)) {
   Import-Module Growl
   Register-GrowlType AutoSign "Signing File" -ErrorAction 0
} else { $NoNotify = $false }

$realItem = Get-Item $Path -ErrorAction Stop
if (-not $realItem) { return } 

$Action = {
   ## Files that can't be signed show up as "UnknownError" with this message:
   $InvalidForm = "The form specified for the subject is not one supported or known by the specified trust provider"
   ## Files that are signed with a cert we don't trust also show up as UnknownError, but with different messages:
   # $UntrustedCert  = "A certificate chain could not be built to a trusted root authority"
   # $InvalidCert = "A certificate chain processed, but terminated in a root certificate which is not trusted by the trust provider"
   # $ExpiredCert = "A required certificate is not within its validity period when verifying against the current system clock or the timestamp in the signed file"
   
   ForEach($file in Get-ChildItem $eventArgs.FullPath | Get-AuthenticodeSignature | 
      Where-Object { $_.Status -ne "Valid" -and $_.StatusMessage -ne $invalidForm } | 
      Select-Object -ExpandProperty Path ) 
   {
      if(!$NoNotify) {
         Send-Growl AutoSign "Signing File" "File $($eventArgs.ChangeType), signing:" "$file"
      }
      if($CertPath) {
         Set-AuthenticodeSignature -FilePath $file -Certificate $CertPath
      } else {
         Set-AuthenticodeSignature -FilePath $file
      }
   }
}
$watcher = New-Object IO.FileSystemWatcher $realItem.Fullname, $filter -Property @{ IncludeSubdirectories = $Recurse }
Register-ObjectEvent $watcher "Created" "AutoSignCreated$($realItem.Fullname)" -Action $Action > $null
Register-ObjectEvent $watcher "Changed" "AutoSignChanged$($realItem.Fullname)" -Action $Action > $null
Register-ObjectEvent $watcher "Renamed" "AutoSignChanged$($realItem.Fullname)" -Action $Action > $null

}

Set-Alias gas          Get-AuthenticodeSignature -Description "Authenticode Module Alias"
Set-Alias sas          Set-AuthenticodeSignature -Description "Authenticode Module Alias"
Set-Alias slas         Select-AuthenticodeSigned -Description "Authenticode Module Alias"
Set-Alias sign         Set-AuthenticodeSignature -Description "Authenticode Module Alias"

Export-ModuleMember -Alias gas,sas,slas,sign -Function Set-AuthenticodeSignature, Get-AuthenticodeSignature, Test-AuthenticodeSignature, Select-AuthenticodeSigned, Get-UserCertificate, Get-AuthenticodeCertificate, Start-AutoSign
