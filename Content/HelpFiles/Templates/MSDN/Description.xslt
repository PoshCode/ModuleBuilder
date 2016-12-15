<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:msxsl="urn:schemas-microsoft-com:xslt" exclude-result-prefixes="msxsl"
    xmlns:command="http://schemas.microsoft.com/maml/dev/command/2004/10"
    xmlns:maml="http://schemas.microsoft.com/maml/2004/10"
    xmlns:dev="http://schemas.microsoft.com/maml/dev/2004/10"
    xmlns:MSHelp="http://msdn.microsoft.com/mshelp"
>
  <xsl:template match="command:command/maml:description">
    <h2 class="heading">Detailed Description</h2>
    <div id="sectionSection2" class="section">
      <xsl:apply-templates />
    </div>
  </xsl:template>

</xsl:stylesheet>
