<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:msxsl="urn:schemas-microsoft-com:xslt" exclude-result-prefixes="msxsl"
    xmlns:command="http://schemas.microsoft.com/maml/dev/command/2004/10"
    xmlns:maml="http://schemas.microsoft.com/maml/2004/10"
    xmlns:dev="http://schemas.microsoft.com/maml/dev/2004/10"
    xmlns:MSHelp="http://msdn.microsoft.com/mshelp"
>
  <xsl:template match="command:syntax">

    <h2 class="heading">Syntax</h2>
    <div id="sectionSection1" class="section">

      <div id="code-snippet-1" class="codeSnippetContainer" xmlns="">
        <div class="codeSnippetContainerTabs"></div>
        <div class="codeSnippetContainerCodeContainer">
          <div class="codeSnippetToolBar">
            <div class="codeSnippetToolBarText">
              <a name="CodeSnippetCopyLink" style="display: none;" title="Copy to clipboard." href="javascript:if (window.epx.codeSnippet)window.epx.codeSnippet.copyCode('CodeSnippetContainerCode_b61eee14-e75f-412f-a73c-a8cfa1eb6a9a');">Copy</a>
            </div>
          </div>
          <div id="CodeSnippetContainerCode_b61eee14-e75f-412f-a73c-a8cfa1eb6a9a" class="codeSnippetContainerCode" dir="ltr">
            <div style="color:Black;">
              <pre>
                <xsl:apply-templates/>
              </pre>
            </div>
          </div>
        </div>
      </div>

      <br />
      <br />
    </div>
  </xsl:template>

  <xsl:template match="command:syntaxItem">
    Parameter Set: Not listed in help file
    <xsl:value-of select="maml:name"/><xsl:apply-templates select="command:parameter" mode="syntax"/> [&lt;CommonParameters>]
  </xsl:template>

  <xsl:template match="command:parameter" mode="syntax">
    <xsl:variable name="pName">
      <xsl:choose>
        <xsl:when test="@position !='named'">
          <xsl:value-of select="concat('[-',maml:name,']')"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="concat('-',maml:name)"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>

    <xsl:variable name="pType">
        <xsl:if test="command:parameterValue !=''">
          <xsl:value-of select="concat(' &lt;', command:parameterValue,'>')"/>
        </xsl:if>
    </xsl:variable>

    <xsl:choose>
      <xsl:when test="@required ='true'">
        <xsl:value-of select="concat(' ',$pName,$pType)"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="concat(' [',$pName,$pType,'] ')"/>
      </xsl:otherwise>
    </xsl:choose>
    
  </xsl:template>
  
</xsl:stylesheet>
