<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:msxsl="urn:schemas-microsoft-com:xslt" exclude-result-prefixes="msxsl"
    xmlns:command="http://schemas.microsoft.com/maml/dev/command/2004/10"
    xmlns:maml="http://schemas.microsoft.com/maml/2004/10"
    xmlns:dev="http://schemas.microsoft.com/maml/dev/2004/10"
    xmlns:MSHelp="http://msdn.microsoft.com/mshelp"
>
  <xsl:template match="command:examples">
    <h2 class="heading">Examples</h2>
    <div id="sectionSection8" class="section">
      <xsl:apply-templates select="command:example"/>
    </div>
  </xsl:template>

  <xsl:template match="command:example">
    <h3 class="subHeading">
      <xsl:value-of select="maml:title"/>
    </h3>
    <div class="subSection">
      <xsl:apply-templates select="dev:remarks"/>
      <br />

      <xsl:apply-templates select="dev:code"/>

    </div>
  </xsl:template>

  <xsl:template match="dev:code">
    <div id="code-snippet-2" class="codeSnippetContainer" xmlns="">
      <div class="codeSnippetContainerTabs">
        <div class="codeSnippetContainerTabSingle" dir="ltr">
          <a>Windows PowerShell</a>
        </div>
      </div>
      <div class="codeSnippetContainerCodeContainer">
        <div class="codeSnippetToolBar">
          <div class="codeSnippetToolBarText">
            <a name="CodeSnippetCopyLink" style="display: none;" title="Copy to clipboard." href="javascript:if (window.epx.codeSnippet)window.epx.codeSnippet.copyCode('CodeSnippetContainerCode_e4e7b17f-c269-4c4b-974c-871164b0a558');">Copy</a>
          </div>
        </div>
        <div id="CodeSnippetContainerCode_e4e7b17f-c269-4c4b-974c-871164b0a558" class="codeSnippetContainerCode" dir="ltr">
          <div style="color:Black;">
            <pre class="brush: PowerShell">
              
                <xsl:value-of select="."/>
              
            </pre>
          </div>

        </div>
      </div>
    </div>
  </xsl:template>

</xsl:stylesheet>
