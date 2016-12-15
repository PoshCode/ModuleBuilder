<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:msxsl="urn:schemas-microsoft-com:xslt" exclude-result-prefixes="msxsl"
    xmlns:command="http://schemas.microsoft.com/maml/dev/command/2004/10"
    xmlns:maml="http://schemas.microsoft.com/maml/2004/10"
    xmlns:dev="http://schemas.microsoft.com/maml/dev/2004/10"
    xmlns:MSHelp="http://msdn.microsoft.com/mshelp"
>
  <xsl:template match="command:details">
    <h2 class="heading">
      <xsl:value-of select="command:name"/>
    </h2>
    <div id="sectionSection0" class="section">
      <xsl:value-of select="maml:description/maml:para"/>
    </div>
    <h2 class="heading">Aliases</h2>
    <div id="sectionSection3" class="section">
      <p>The following abbreviations are aliases for this cmdlet:</p>
      <ul>
        <li class="unordered">Currently not found in the Help XML</li>
      </ul>
    </div>
  </xsl:template>
</xsl:stylesheet>
