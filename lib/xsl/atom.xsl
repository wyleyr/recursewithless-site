<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:atom="http://www.w3.org/2005/Atom">

  <xsl:output method="html" indent="yes"/>

  <xsl:template match="/">
    <html>
      <head>
        <title>recursewithless.net atom feed</title>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=yes" />
        <meta name="author" content="Richard W. Lawrence" />
        <meta name="description" content="Updates from recursewithless.net" />
        <xsl:apply-templates select="/atom:feed/atom:updated" mode="meta-date" />
        <link rel="license" href="https://creativecommons.org/licenses/by-sa/4.0/"/>
        <link rel="self" type="application/atom+xml" href="/atom.xml" />
        <link rel="stylesheet" href="/lib/css/base.css" />
      </head>
      <body>
        <main id="root">
        <aside class="banner">
          <p>
            <img src="/lib/img/Feed-icon.svg" style="height: 1em; margin-right: 1em;"/> 
            <strong>This is a feed.</strong>
          </p>
          <p>
            A feed is a way for you to get updates from a website. 
            For more information, see
            <a href="https://aboutfeeds.com">aboutfeeds.com</a> or
            <a href="https://en.wikipedia.org/wiki/Web_feed">Wikipedia</a>.
          </p>
          <p>
            You can subscribe to this feed using a feed reader, like:
            <ul>
              <li>the <a href="https://nodetics.com/feedbro/">Feedbro reader extension</a> for
                <a href="https://addons.mozilla.org/en-US/firefox/addon/feedbroreader/">Firefox</a>,
                <a href="https://chrome.google.com/webstore/detail/feedbro/mefgmmbdailogpfhfblcnnjfmnpnmdfa">Chrome</a>, or
                <a href="https://microsoftedge.microsoft.com/addons/detail/feedbro/pdfbckdfhgaohcfdkcgpggcifmalimfd">Edge</a>
              </li>
              <li>the <a href="https://support.mozilla.org/en-US/kb/how-subscribe-news-feeds-and-blogs">Thunderbird</a>
              mail client </li>
              <li>the <a href="https://github.com/skeeto/elfeed">elfeed</a> package for GNU Emacs</li>
            </ul>
            Just paste the URL above into your feed reader's subscribe function.
            Then you won't have to keep checking back here for updates.
            (But of course you can do that too.)
          </p>
        </aside>
          <h1>Updates at recursewithless.net</h1>
          <ol>
            <xsl:apply-templates select="//atom:entry" mode="li"/> 
          </ol>
        </main>
      </body>
    </html>
  </xsl:template>

  <xsl:template match="atom:entry" mode="li">
    <li>
      <p>
        <xsl:apply-templates select="./atom:updated" mode="time"/>:
        <strong><xsl:value-of select="./atom:title/text()" /></strong>:
        <xsl:apply-templates select="./atom:link" mode="a"/>
      </p>
      <p>
        <xsl:value-of select="./atom:summary/text()" />
      </p>
    </li>
  </xsl:template>

  <xsl:template match="atom:link" mode="a">
    <xsl:element name="a">
       <xsl:attribute name="href">
         <xsl:value-of select="./@href"/>
       </xsl:attribute>
       <xsl:value-of select="./@href"/>
    </xsl:element>
  </xsl:template>

  <xsl:template match="atom:updated" mode="meta-date">
    <xsl:element name="meta">
      <xsl:attribute name="name">dcterms.date</xsl:attribute>
      <xsl:attribute name="content">
        <xsl:value-of select="text()"/>
      </xsl:attribute>
    </xsl:element>
  </xsl:template>

  <xsl:template match="atom:updated" mode="time">
    <xsl:element name="time">
       <xsl:attribute name="datetime">
         <xsl:value-of select="text()"/>
       </xsl:attribute>
       <xsl:value-of select="substring-before(text(),'T')"/>
    </xsl:element>
  </xsl:template>

</xsl:stylesheet>
