#! requires -Module ModuleBuilder
Describe "CompressToBase64" {

    Context "It compresses and encodes a file for embedding into a script" {
        BeforeAll {
            $Base64 = InModuleScope ModuleBuilder {
                CompressToBase64 $PSCommandPath
            }
        }

        It "Returns a base64 encoded string" {
            $Base64 | Should -BeOfType [string]
            $Base64 | Should -Match "^[A-Za-z0-9\+\/]+=*$"
            $Base64.Length | Should -BeGreaterThan 0
        }

        It "Returns the gzipped and encoded script" {
            $OutputStream = [System.IO.MemoryStream]::new()
            $InputStream = [System.IO.MemoryStream][System.Convert]::FromBase64String($Base64)
            $DeflateStream = [System.IO.Compression.DeflateStream]::new($InputStream, [System.IO.Compression.CompressionMode]::Decompress)
            $DeflateStream.CopyTo($OutputStream)
            $OutputStream.Seek(0, "Begin")
            $Source = [System.IO.StreamReader]::new($OutputStream, $true).ReadToEnd()

            $Source | Should -Be (Get-Content $PSCommandPath -Raw)
        }
    }

    Context "It wraps the Base64 encoded content in the specified command" {
        BeforeAll {
            $Base64 = InModuleScope ModuleBuilder {
                CompressToBase64 $PSCommandPath -ExpandScriptName ImportBase64Module
            }
        }

        It "Returns a string" {
            $Base64 | Should -BeOfType [string]
        }

        It "Pipes the encoding into the command" {
            $Block = InModuleScope ModuleBuilder {
                (Get-Command ImportBase64Module).ScriptBlock
            }

            $Base64 | Should -Match "|.{`n$Block`n}$"
        }
    }

    Context "It wraps the Base64 encoded content in the specified scriptblock" {
        BeforeAll {
            $Base64 = InModuleScope ModuleBuilder {
                Get-ChildItem $PSCommandPath | CompressToBase64 -ExpandScript { ImportBase64Module }
            }
        }

        It "Returns a string" {
            $Base64 | Should -BeOfType [string]
        }
        It "Pipes the encoding into the scriptblock" {
            $Base64 | Should -Match "|.{`nImportBase64Module`n}$"
        }
    }
}
