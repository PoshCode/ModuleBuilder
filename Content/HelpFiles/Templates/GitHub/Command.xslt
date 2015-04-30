<?xml version="1.0" encoding="utf-8"?>

<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:msxsl="urn:schemas-microsoft-com:xslt" exclude-result-prefixes="msxsl"
    xmlns:command="http://schemas.microsoft.com/maml/dev/command/2004/10"
    xmlns:maml="http://schemas.microsoft.com/maml/2004/10"
    xmlns:dev="http://schemas.microsoft.com/maml/dev/2004/10"
    xmlns:MSHelp="http://msdn.microsoft.com/mshelp"
>

  <xsl:output method="html" version="4.0" encoding="UTF-8" indent="yes"/>
  <xsl:include href="General.xslt"/>
  <xsl:include href="Detail.xslt"/>
  <xsl:include href="Syntax.xslt"/>
  <xsl:include href="Description.xslt"/>
  <xsl:include href="Parameters.xslt"/>
  <xsl:include href="Inputs.xslt"/>
  <xsl:include href="Outputs.xslt"/>
  <xsl:include href="Notes.xslt"/>
  <xsl:include href="Examples.xslt"/>
  <xsl:include href="Related.xslt"/>

  <!-- This is the ROOT xslt-->
  <xsl:template match="command:command">

    <html dir="ltr" xmlns="http://www.w3.org/1999/xhtml" lang="en">
      <head>
        <link type="text/css" rel="stylesheet" href="http://jrich523.github.io/NimblePowerShell/stylesheets/stylesheet.css"/>
        <link href="http://jrich523.github.io/NimblePowerShell/stylesheets/github-light.css" rel="stylesheet" type="text/css" media="screen"/>
          
        <title>
          <xsl:value-of select="command:details/command:name"/>
        </title>
      </head>
      <body>

        <!-- Header Template-->
        <div id="header_wrap" class="outer">
          <header class="inner, page-header">
            <h1 id="project_title" class="project-name">
              <xsl:value-of select="command:details/command:name"/>
            </h1>
            <h2 id="project_tagline" class="project-tagline">
              Windows PowerShell 4.0 - Updated: December 3, 2014
            </h2>
          </header>
        </div>

        <!--Body template-->
        <div id="main_content_wrap" class="outer">
          <section id="main_content" class="inner, main-content">
            <xsl:apply-templates/>
          </section>
        </div>

      </body>
    </html>

  </xsl:template>
</xsl:stylesheet>