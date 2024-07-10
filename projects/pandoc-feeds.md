---
title: Generating Atom and RSS with Pandoc
date: 2024-07-07
---

## On feeds

As part of revamping and reorganizing my site recently, I decided to
add support for Atom and RSS feeds. I know I am a little behind the
times here. Feeds on the Web had a big moment more than ten years ago,
but since [Google Reader was shut
down](https://en.wikipedia.org/wiki/Google_Reader#Discontinuation),
they have mostly lived a kind of shadow existence. The other big tech
companies stopped supporting them, and many people aren't even aware
that they exist anymore. Browsers don't make them obvious or have
built-in tools to subscribe to them, though you can still get
[add-ons](https://nodetics.com/feedbro/).

But feeds are still around, and still an important part of the
independent Web, and so in the name of being the change you want to
see in the world, I put one together for my site.

## Pandoc

I use [Pandoc](https://pandoc.org/) to generate the HTML on this site
from Markdown input. Pandoc has two features that can be repurposed to
generate feeds: it has a [citation
processor](https://pandoc.org/MANUAL.html#citations) which allows
storing bibliographic information in a YAML metadata file, and it has
a [templating system](https://pandoc.org/MANUAL.html#templates) where
that metadata is exposed.

A feed is, basically, just a series of citations to webpages---that
is, hyperlinks!---together with some other metadata which is also used
in bibliographies, like a title and an author. So by writing a YAML
file containing the "citation" data representing the feed entries and
processing it with an Atom or RSS template, you can output valid Atom
and RSS feeds with Pandoc.

### Metadata file {#metadata data-tocd="representing feed entries"}

I save the citation metadata in a file called `feeds.yaml`, which 
looks like this:

```
title: recursewithless.net
references:
- title: Generating Atom and RSS feeds with Pandoc
  issued: 2024-07-07
  URL: https://recursewithless.net/projects/pandoc-feeds.html
  abstract: How I set up feeds for recursewithless.net
- title: Chairs restoration project
  issued: 2024-07-04
  URL: https://recursewithless.net/projects/chairs-restoration.html
  abstract: I bought some 120 year old chairs and they needed some
  work
...
```

There is a `title` field for the whole feed, and then a list of
`references` representing updates on the site, each of which has a
`title`, an `URL`, an `issued` date, and possibly an `abstract` (which
could contain as much content as you like, including a copy of a whole
post or page). It's simple metadata in a format which is easy to
update and keep tidy by hand.

One could generate this file from the contents of other files---say,
all the files in a `blog/` subdirectory---but for now I want to keep
things simple. Maintaining the file by hand makes it easy to represent
multiple updates to the same page as different entries in the feed,
and to tailor the `abstract` for feed readers.

## Atom

### Atom template {data-tocd="for Atom feeds"}

To generate an Atom feed from this metadata, we need a template.
Here's what mine looks like: 

```
<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <author>
    <name>rwl</name>
    <email>rwl@recursewithless.net</email>
  </author>
  <title>$title$</title>
  <id>https://recursewithless.net/</id>
  <link rel="self" href="https://recursewithless.net/atom.xml" />
  <updated>$updated$</updated>

  $for(references)$
  <entry>
    <id>$references.URL$</id>
    <title>$references.title$</title>
    <updated>$references.issued$T00:00:00+02:00</updated>
    <link href="$references.URL$" />
    <summary>$references.abstract$</summary>
  </entry>
  $endfor$
</feed>
```

There's a header with some metadata (author, title, id, link) for the
whole feed, followed by a list of `<entry>` items. These
are generated by looping over the `references` variable in the
metadata. 

The only notable things here are the dates: the header contains an
`<updated>` tag representing the last time the whole feed
was updated---about which more momentarily. There is also an
`updated` tag for each `entry`.

Unfortunately, the Atom and RSS standards require dates to be
represented in *different* formats: Atom uses [RFC
3339](https://www.rfc-editor.org/rfc/rfc3339), while RSS uses the much
older [RFC 822](https://www.ietf.org/rfc/rfc822.txt). As a best effort
to support them both I decided to keep the dates in *YYYY-MM-DD* format
in the metadata. To get that into full RFC-3339 format which passes
the [W3C's feed validator](https://validator.w3.org/feed/), I append a
timestamp for midnight in my timezone after the `issued` field
of each entry: `T00:00:00+02:00`.

### Atom Makefile recipe {#atom-recipe data-tocd="Makefile entry"}

I then run Pandoc via a Makefile recipe to generate the actual Atom
feed file, which I called `atom.xml`, and which is included in
the build for my whole site:

```
atom.xml: feeds.yaml lib/templates/atom.xml
	pandoc -M updated="$$(date --iso-8601='seconds')"\
		--metadata-file=feeds.yaml \
		--template=lib/templates/atom.xml \
		-t html \
		-o atom.xml < /dev/null
```
Note that I set an additional metadata variable (`-M`) here called
`updated` using the Unix `date` program. This gives the
date and time when the build actually runs, which is filled into the
`updated` tag in the feed header. For some 
reason, despite what the standards say, `date`'s RFC 3339
output format (which looks like `2024-07-07 20:06:00+02:00`)
doesn't pass the W3C's Atom validator, but its ISO 8601 output format
(which looks like `2024-07-07T20:06:00+02:00`; note the "T")
does, so that's what I'm using. I'm not sure whether the validator or
my version of `date` is wrong; if you know, please explain to
me what I should do here. 

I tell Pandoc that it's generating "HTML" (`-t html`), even though
it's really generating XML, just to suppress a warning about an
unknown output format. And I redirect standard input from `/dev/null`
because there is no additional input file that needs to be
processed---just the metadata file. (Without this, Pandoc waits
forever for input from the terminal.)

And that's it!

## RSS

RSS is basically the same, but there are a couple of quirks to take
care of, again related to dates.

### RSS template {data-tocd="for RSS feeds"}

Here's the template for RSS:

```
<?xml version="1.0" encoding="UTF-8" ?>
<rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom">
<channel>
 <title>$title$</title>
 <description>Updates from rwl</description>
 <link>https://recursewithless.net/</link>
 <atom:link href="https://recursewithless.net/rss.xml" rel="self" type="application/rss+xml" />
 <lastBuildDate>$updated$</lastBuildDate>
 <ttl>1440</ttl>

 $for(references)$
 <item>
  <title>$references.title$</title>
  <description>$references.abstract$ (Updated $references.issued$)</description>
  <link>$references.URL$</link>
  <guid>$references.URL$@$references.issued$</guid>
 </item>
 $endfor$
</channel>
</rss>
```

Basically the same exact information here, just slightly different tag
names. The validator recommends adding the `<atom:link rel="self" ...>` element with the URL of the feed itself, as in Atom. It
also recommends a `<guid>` element for each item in the
feed with a unique identifier for the item, which is allowed to be any
text. I combine the URL with the date there so that different updates
to the same URL on different days will get different identifiers.

Note also that I don't put any `<pubDate>` tag in the
items. This is because according to the standard, that element can only
contain an RFC 822 date, and I couldn't see a way to convert 
YYYY-MM-DD dates to RFC 822 within Pandoc's templating system.
Fortunately, `<pubDate>` is optional, so I just leave it
out and instead put the `issued` date in a note at the the end
of the `<description>` tag.

### RSS Makefile recipe {#rss-recipe data-tocd="Makefile entry"}

Finally, here's the Makefile recipe for the RSS feed:

```
rss.xml: feeds.yaml lib/templates/rss.xml
	pandoc -M updated="$$(date '+%a, %d %b %Y %T %z')"\
		--metadata-file=feeds.yaml \
		--template=lib/templates/rss.xml \
		-t html \
		-o rss.xml < /dev/null
```

Again, everything is the same as for Atom, except that my version of
`date` doesn't have a built-in RFC 822 output, so I generate it
directly with a format string that satisfies the W3C's validator.

And with that, I can put a new entry in `feeds.yaml`, run `make all`,
and my website feeds get updated along with the rest of it!