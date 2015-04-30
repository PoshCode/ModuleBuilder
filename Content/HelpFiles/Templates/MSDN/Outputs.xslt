<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:msxsl="urn:schemas-microsoft-com:xslt" exclude-result-prefixes="msxsl"
    xmlns:command="http://schemas.microsoft.com/maml/dev/command/2004/10"
    xmlns:maml="http://schemas.microsoft.com/maml/2004/10"
    xmlns:dev="http://schemas.microsoft.com/maml/dev/2004/10"
    xmlns:MSHelp="http://msdn.microsoft.com/mshelp"
>
  <xsl:template match="command:returnValues">

    <h2 class="heading">Outputs</h2>
    <div id="sectionSection6" class="section">
      <p>The output type is the type of the objects that the cmdlet emits.</p>
      <ul>
        <li class="unordered">
          <xsl:apply-templates/>
        </li>
      </ul>
    </div>

  </xsl:template>

  <xsl:template match="command:returnValue">

    <strong>
      <xsl:value-of select="dev:type/maml:name"/>
    </strong>
    <xsl:apply-templates select="maml:description"/>
    <br />

  </xsl:template>

</xsl:stylesheet>
