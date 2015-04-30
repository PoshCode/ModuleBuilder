<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:msxsl="urn:schemas-microsoft-com:xslt" exclude-result-prefixes="msxsl"
    xmlns:command="http://schemas.microsoft.com/maml/dev/command/2004/10"
    xmlns:maml="http://schemas.microsoft.com/maml/2004/10"
    xmlns:dev="http://schemas.microsoft.com/maml/dev/2004/10"
    xmlns:MSHelp="http://msdn.microsoft.com/mshelp"
>

  <!-- This hold all general type, typical maml based-->

  <xsl:template match="maml:description">
      <xsl:apply-templates />
  </xsl:template>
  <xsl:template match="maml:para">
    <p>
      <xsl:apply-templates />
    </p>
  </xsl:template>
  
</xsl:stylesheet>
