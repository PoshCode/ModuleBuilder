<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:msxsl="urn:schemas-microsoft-com:xslt" exclude-result-prefixes="msxsl"
    xmlns:command="http://schemas.microsoft.com/maml/dev/command/2004/10"
    xmlns:maml="http://schemas.microsoft.com/maml/2004/10"
    xmlns:dev="http://schemas.microsoft.com/maml/dev/2004/10"
    xmlns:MSHelp="http://msdn.microsoft.com/mshelp"
>


  <xsl:template match="command:parameters">

    <h2 class="heading">Parameters</h2>
    <div id="sectionSection4" class="section">
      <xsl:apply-templates select="command:parameter" mode="paramList"/>
    </div>

  </xsl:template>

  <xsl:template match="command:parameter" mode="paramList">

    <h3 class="subHeading">
      <xsl:value-of select="concat('-',maml:name,'&lt;',dev:type/maml:name,'>')"/>
    </h3>

    <div class="subSection">
      <xsl:apply-templates select="maml:description"/>
      <br />
      <table class="parameterset">
        <tr>
          <td>
            <p>Aliases</p>
          </td>
          <td>
            <p>
              <xsl:choose>
                <xsl:when test="@aliases != ''">
                  <xsl:value-of select="@aliases" />
                </xsl:when>
                <xsl:otherwise>
                  <xsl:text>none</xsl:text>
                </xsl:otherwise>
              </xsl:choose>
            </p>
          </td>
        </tr>
        <tr>
          <td>
            <p>Required?</p>
          </td>
          <td>
            <p>
              <xsl:value-of select="@required"/>
            </p>
          </td>
        </tr>
        <tr>
          <td>
            <p>Position?</p>
          </td>
          <td>
            <p>
              <xsl:value-of select="@position"/>
            </p>
          </td>
        </tr>
        <tr>
          <td>
            <p>Default Value</p>
          </td>
          <td>
            <p>
              <xsl:choose>
                <xsl:when test="dev:defaultValue != ''">
                  <xsl:value-of select="dev:defaultValue" />
                </xsl:when>
                <xsl:otherwise>
                  <xsl:text>none</xsl:text>
                </xsl:otherwise>
              </xsl:choose>
            </p>
          </td>
        </tr>
        <tr>
          <td>
            <p>Accept Pipeline Input?</p>
          </td>
          <td>
            <p>
              <xsl:value-of select="@pipelineInput"/>
            </p>
          </td>
        </tr>
        <tr>
          <td>
            <p>Accept Wildcard Characters?</p>
          </td>
          <td>
            <p>
              <xsl:value-of select="@globbing"/>
            </p>
          </td>
        </tr>
      </table>
    </div>

  </xsl:template>

</xsl:stylesheet>
