<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:msxsl="urn:schemas-microsoft-com:xslt" exclude-result-prefixes="msxsl"
    xmlns:command="http://schemas.microsoft.com/maml/dev/command/2004/10"
    xmlns:maml="http://schemas.microsoft.com/maml/2004/10"
    xmlns:dev="http://schemas.microsoft.com/maml/dev/2004/10"
    xmlns:MSHelp="http://msdn.microsoft.com/mshelp"
>
  <xsl:template match="command:inputTypes">

    <h2 class="heading">Inputs</h2>
    <div id="sectionSection5" class="section">
      <p>The input type is the type of the objects that you can pipe to the cmdlet.</p>
      <ul>
        <li class="unordered">
          <xsl:apply-templates/>
        </li>
      </ul>
    </div>

  </xsl:template>

  <xsl:template match="command:inputType">

    <strong>
      <xsl:value-of select="dev:type/maml:name"/>
    </strong>
    <xsl:apply-templates select="maml:description"/>
    <br />

  </xsl:template>
  
</xsl:stylesheet>
