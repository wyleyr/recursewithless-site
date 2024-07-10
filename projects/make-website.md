---
title: make is my website build system
---

## make

I use [GNU make](https://www.gnu.org/software/make/) to build
my website (and other things). Make is a program that lets you
define *recipes* for transforming some ingredients into some tastier
product (or 'prerequisites' into a 'target', in boring
documentation-speak). A recipe looks like this:

```
some_product: ingredient1 ingredient2...
	do_some_steps
```

I use it, for example, to transform the Markdown files where I write
these pages into the HTML that gets sent to your browser. In that
case, a Markdown file is the ingredient, the HTML file is the product,
and the recipe has one step: convert the Markdown file to HTML using
[Pandoc](https://pandoc.org/). A very simple make recipe for making,
say, `index.html` from `index.md` might look like this:

```
index.html: index.md
	pandoc -f markdown -t html -o index.html index.md
```

This recipe tells make: "build `index.html` from `index.md` by running
the command `pandoc -f markdown -t html -o index.html index.md`."
You write this recipe in a file called `Makefile` in the same
directory. Once you write the recipe, you can run `make index.html` in
that directory and make will follow the recipe, running Pandoc for you
to produce `index.html`.

Why go to all this trouble? Why not just run the `pandoc` command
yourself? Well, for one thing, `make index.html` is shorter to type
into your shell. For another, recording your recipe makes the process
repeatable and reliable. This is very useful for more complex recipes,
which might have several steps, any of which can suffer from typos or
forgotten arguments if you type them in manually.

Finally, make uses the timestamps on files to determine which targets
actually need to be rebuilt. If the ingredients haven't changed,
there's no need to rebuild the product, so make will skip it. This is
also useful in more complex situations, where the product of one
recipe is an ingredient for another---like the individual HTML
pages needed to make a complete website.

Make gets a lot of hate from the types of programmers who call
themselves 'engineers' and work at companies with million-line
codebases. "It's old; it's crufty; it's complex and cryptic." Sure.
Like most things Unix, make *can* be all of those, and it wasn't
designed for compiling those million-line codebases.

But for the hobby programmer, the working academic, the independent
researcher, or anyone else who needs to use a computer to transform
some input files into output files---so basically, anyone who is using
a computer to do anything useful---it's a very handy tool and well
worth learning. Recipes needn't be complicated or cryptic, and having
them recorded can save you a lot of time and help you keep a project
organized.

## my website's Makefile {#Makefile data-tocd="for my site"}

I recently set out to clean up and restructure the Makefile I use to
generate this site, which required me to dig into the
[documentation](https://www.gnu.org/software/make/manual/make.html) a
bit. I am by no means the first person to use make to generate my
site, but I thought it would be worth recording my approach.

Here is my site's Makefile, as of this writing:

```
all: 	build/index.html \
	$(addprefix build/, $(wildcard lib/css/*.css)) \
	$(addprefix build/, $(wildcard lib/js/*.js)) \
	$(addprefix build/, $(wildcard lib/img/*)) \
	build/cv/index.html \
	build/photos/index.html \
	$(addprefix build/, $(wildcard photos/*.jpg)) \
	build/projects/index.html \
	build/projects/chairs-restoration.html \
	$(addprefix build/, $(wildcard projects/img/chairs/*)) \
	build/projects/pandoc-feeds.html \
	build/emacs/index.html \
	$(addprefix build/, $(wildcard emacs/*.org))

%.html: %.md lib/templates/template.html lib/css/base.css
	pandoc -f markdown+multiline_tables+implicit_figures+link_attributes+raw_html -t html \
		--section-divs \
		--standalone \
		--template lib/templates/template.html \
		-o $@ $<

build/%: %
	mkdir -p $(@D) 
	cp $< $@ 

clean:
	rm -r build/*
```

(To keep things concise, I have removed the recipes related to feeds
but see [how I generate feeds with make and Pandoc](./pandoc-feeds.html) if you're curious.)

There are four recipes here, which do the following:

1. Record all the files that should appear in the `build/` directory,
   which contains the finished website
1. Build HTML files from Markdown files
1. Copy files from the source tree into the `build/` directory
1. Clean up the `build/` directory if I want to start fresh

### The `all` recipe {#all data-tocd="the whole site"}

The `all` target has a long list of prerequisites: it is a list of all
the files that should exist in the `build/` directory to be published
on the website. Some of them are listed explicitly by name, and others
are listed using wildcards.

For example, this line
```
	$(addprefix build/, $(wildcard lib/img/*)) \
```
tells make to take all the filenames under `lib/img` and add `build/`
in front of them: if `lib/img/` contains `A.jpg` and `B.png`, this
expands to `build/lib/img/A.jpg build/lib/img/B.png`. I can't just
write `build/lib/img/*` here because (on a fresh build) those files
don't yet exist, so there's nothing for the `*` to match. Instead, we
have to build the list of filenames we want using the `wildcard` and
`addprefix` functions. The `wildcard` function expands the `*` in the
`lib/img` directory (where there *are* files for it to match), and the
call to the `addprefix` function then prefixes `build/` to *each* of
those names.

Notice that this recipe is empty: running `make all` just ensures that
each of the prerequisites in `build/` exists. If they do, no further
commands are needed. If they don't, make figures out how to build them
using one of the following recipes.

Also, since this is the first recipe in the Makefile, [make runs it by
default](https://www.gnu.org/software/make/manual/make.html#How-Make-Works).
So I don't even need to type `make all` to build the whole site: I
just type `make`.

### The `%.html` target {#html data-tocd="making HTML files"}

Here is the important part of the next recipe:

```
%.html: %.md ...
	pandoc ... -o $@ $<
```

The `%` in the target means this is a so-called [pattern
rule](https://www.gnu.org/software/make/manual/make.html#Pattern-Rules).
The pattern `%.html` matches against any target that ends in `.html`.
The `%.md` prerequisite pattern must match the same 'stem' as the
target: if the target is `cv.html`, then the prerequisite is `cv.md`,
and so on. Thus, this recipe says how to build *any* HTML file from
the corresponding `.md` file.

But the steps in the recipe must be run with the actual filenames, of
course. This is where [automatic
variables](https://www.gnu.org/software/make/manual/make.html#Automatic-Variables)
enter the stage. These are variables whose values make fills in based on the
patterns.

`$@` is an automatic variable which contains the actual file name in
the target (e.g., `cv.html`). Thus it is given as the `-o` argument to
the `pandoc` command, which specifies the output file that Pandoc
should produce. `$<` contains the file name in the first prerequisite
(e.g., the corresponding `cv.md`). Thus it is passed (without a flag)
as the name of the input file to `pandoc`.

This is where `make` starts to look a little cryptic. But see how `@`
looks like a little target? and `<` is pointing to the left, i.e., the
start of the list? There are at least some visual cues to help you
remember what these automatic variables mean.

### The `build/%` target {#build data-tocd="copying files to build/"}

The next recipe is also based on a pattern:

```
build/%: %
	mkdir -p $(@D) 
	cp $< $@ 
```

Here again, the `build/%` target matches any file name that starts with
`build/`, so it matches all the prequisites of the `all` recipe. The
bare `%` prerequisite matches the part of the target without the `build/`
prefix.  So if `build/lib/img/selfportrait.png` is the target (`$@`), then
`lib/img/selfportrait.png` is the first (and only) prerequisite (`$<`).

All this recipe does is take care of copying files into the `build/`
directory: notice that we `cp` the prerequisite `$<` to the target `$@`.
But since the prerequisite might be several directories deep, we first
need to make sure the corresponding directory structure exists under
`build` with the `mkdir -p` command. Here I use another automatic
variable: `$(@D)` contains the *directory part* of the filename in the
target.  So if `build/lib/img/selfportrait.png` is the target, `$(@D)`
contains `build/lib/img/`.

So fully expanded for this example, the recipe looks like:

```
build/lib/img/selfportrait.png: lib/img/selfportrait.png
	mkdir -p build/lib/img 
	cp lib/img/selfportrait.png build/lib/img/selfportrait.png
```

And with that, I have everything I need to build the complete website
with `make all`: the `%.html` recipe says how to make HTML files from
Markdown files, the `build/%` recipe says how to copy files into the
`build` directory, and the `all` recipe says which files should be in
the `build` directory.

### The `clean` target {#clean data-tocd="starting fresh"}

Finally, we have the `clean` target. This is a standard Makefile
convention: a phony target that deletes all the files produced by the
build, so you can start fresh from a clean copy if something goes
wrong. Here I just delete all the files in the `build/*` directory
recursively.

If you're a particularly sharp-eyed reader, you might be asking: don't
you also need to delete the `.html` files which first get built from
the `.md` files in the source tree?

The answer is *no*, because make automatically deletes these files,
which surprised me at first. [The
manual explains why](https://www.gnu.org/software/make/manual/make.html#Chained-Rules):

> Intermediate files are remade using their rules just like all other
> files. But intermediate files are treated differently ...
>
> if make does create b in order to update something else, it deletes
> b later on after it is no longer needed. Therefore, **an intermediate
> file which did not exist before make also does not exist after make**.
> make reports the deletion to you by printing a ‘rm’ command showing
> which file it is deleting.

Given the way I've structured the Makefile, a `.html` in the source
tree is an intermediate file, only needed so that it can be copied
into the `build/` directory by the `build/%` recipe. So once the
copying is done, make deletes it automatically, and I don't need to
delete it explicitly in the `clean` recipe.
