<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:msxsl="urn:schemas-microsoft-com:xslt" exclude-result-prefixes="msxsl"
    xmlns:command="http://schemas.microsoft.com/maml/dev/command/2004/10"
    xmlns:maml="http://schemas.microsoft.com/maml/2004/10"
    xmlns:dev="http://schemas.microsoft.com/maml/dev/2004/10"
    xmlns:MSHelp="http://msdn.microsoft.com/mshelp"
>
  <xsl:template match="maml:alertSet">
    
    <h2 class="heading">Notes</h2>
    <div id="sectionSection7" class="section">
      <ul>
        <xsl:apply-templates select="maml:alert"/>
      </ul>
    </div>
    
  </xsl:template>

  <xsl:template match="maml:alert">
    <li class="unordered">
      <xsl:apply-templates select="maml:para"/>
    </li>
  </xsl:template>
  
</xsl:stylesheet>
