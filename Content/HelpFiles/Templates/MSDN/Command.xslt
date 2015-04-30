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
        <link rel="canonical" href="https://technet.microsoft.com/en-us/library/hh849832.aspx" />
        <title><xsl:value-of select="command:details/command:name"/></title>
        <link rel="stylesheet" type="text/css" href="https://i-technet.sec.s-msft.com/Combined.css?resources=0:Topic,0:CodeSnippet,0:ProgrammingSelector,0:ExpandableCollapsibleArea,1:CommunityContent,0:TopicNotInScope,0:FeedViewerBasic,0:ImageSprite,2:Header.1,3:PrintExportButton,1:Toc,1:NavigationResize,0:VersionSelector,4:Feedback,1:LibraryMemberFilter,2:Footer.1,5:LinkList,0:SiteFeedbackLink,5:Base,6:TechNet;/Areas/Epx/Content/Css:0,/Areas/Library/Content:1,/Areas/Epx/Themes/TechNet/Content:2,/Areas/Library/Themes/Base/Content:3,/Areas/Epx/Shared/Content:4,/Areas/Epx/Themes/Base/Content:5,/Areas/Library/Themes/TechNet/Content:6&amp;amp;v=8595E0AFEB0ECC02F1E44178DC625769" />
      </head>
      <body class="library Chrome">
        <div id="page">
          <link type="text/css" rel="stylesheet" href="https://i-technet.sec.s-msft.com/Areas/EPX/Themes/Shared/Content/Megablade.1.css?v=635651651043682771" data-do-not-move="true" />
          <div id="body">
            <div id="content" class="content">
              <div xmlns="http://www.w3.org/1999/xhtml">
                <div class="topic" xmlns="http://www.w3.org/1999/xhtml" xmlns:mtps="http://msdn2.microsoft.com/mtps" xmlns:msxsl="urn:schemas-microsoft-com:xslt" xmlns:cs="http://msdn.microsoft.com/en-us/">
                  <!-- Header Template-->
                  <h1 class="title"><xsl:value-of select="command:details/command:name"/></h1>
                  <div class="lw_vs">
                    <div id="curversion">
                      <strong>
                        -Windows PowerShell 4.0-
                      </strong>
                    </div>
                  </div>
                  <div style="clear:both;"></div>

                  <p>-Updated: December 3, 2014-</p>
                  <p>-Applies To: Windows PowerShell 4.0-</p>
                  <div id="mainSection">
                    <!--Body template-->
                    <div id="mainBody">
                      <xsl:apply-templates/>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
          <div class="clear"></div>
        </div>
      </body>
    </html>

  </xsl:template>
</xsl:stylesheet>