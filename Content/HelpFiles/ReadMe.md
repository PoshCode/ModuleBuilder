#Help File HTML Rendering#

This content is what is used to render your XML help files as HTML. When hosting a module on GitHub the Pages branch will have links to the help files and this is what defines the format of help files.

The goal is to have the majority of this configuration automatic but at this point its just a sample rendering.

This document will require more details once the whole process is sorted out.


##Configuration##
When these files get deployed to the hosting site the XML help files should have a style sheet reference in them this:

	<?xml-stylesheet type="text/xsl" href="Help_Style.xslt"?>

Again this is something that should be automatically handled in the end.

The href will vary depending on where the xml files are vs the location of these XSLTs. They should always point to the **Help_Style.xslt** which is a simple pointer to the style you'd like.

To change the Theme/Style you'd like just change the **Help_Style.xslt** to point to the template you prefer. It should look something like this

	  <xsl:import href = "Templates/MSDN/Command.xslt"/>


###NOTE###
Currently the GitHub style is hard coded to a personal project for testing based on its used CSS. It looks like due to the variations in the different GitHub Pages themes that it might not be possible to have it mirror the selected theme. 
