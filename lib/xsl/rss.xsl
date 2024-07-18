<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:output method="html" indent="yes"/>

  <xsl:template match="/">
    <html>
      <head>
        <title>recursewithless.net RSS feed</title>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=yes" />
        <meta name="author" content="Richard W. Lawrence" />
        <meta name="description" content="Updates from recursewithless.net" />
        <link rel="license" href="https://creativecommons.org/licenses/by-sa/4.0/"/>
        <link rel="self" type="application/rss+xml" href="/rss.xml" />
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
            <xsl:apply-templates select="//item" mode="li"/> 
          </ol>
        </main>
      </body>
    </html>
  </xsl:template>

  <xsl:template match="item" mode="li">
    <li>
      <p>
        <strong><xsl:value-of select="./title/text()" /></strong>:
        <xsl:apply-templates select="./link" mode="a"/>
      </p>
      <p>
        <xsl:value-of select="./description/text()" />
      </p>
    </li>
  </xsl:template>

  <xsl:template match="link" mode="a">
    <xsl:element name="a">
       <xsl:attribute name="href">
         <xsl:value-of select="text()"/>
       </xsl:attribute>
       <xsl:value-of select="text()"/>
    </xsl:element>
  </xsl:template>

</xsl:stylesheet>
