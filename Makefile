all: 	build/index.html \
	build/atom.xml \
	build/rss.xml \
	$(addprefix build/, $(wildcard lib/css/*.css)) \
	$(addprefix build/, $(wildcard lib/xsl/*.xsl)) \
	$(addprefix build/, $(wildcard lib/js/*.js)) \
	$(addprefix build/, $(wildcard lib/img/*)) \
	build/cv/index.html \
	build/cv/cv.pdf \
	build/texts/index.html \
	build/texts/2023-04-03portugaltour.html \
	build/photos/index.html \
	$(addprefix build/, $(wildcard photos/*.jpg)) \
	build/photos/portugaltour2023.html \
	$(addprefix build/, $(wildcard photos/img/2023/portugaltour/*.jpg)) \
	build/projects/index.html \
	build/projects/chairs-restoration.html \
	$(addprefix build/, $(wildcard projects/img/chairs/*)) \
	build/projects/pandoc-feeds.html \
	build/projects/make-website.html \
	build/reading/index.html \
	$(addprefix build/, $(wildcard reading/ebooks/*)) \
	build/emacs/index.html \
	build/emacs/org-basic-agenda.html \
	build/emacs/mnemonic-keymaps.html \
	$(addprefix build/, $(wildcard emacs/*.org)) 

%.html: %.md lib/templates/template.html lib/css/base.css
	pandoc -f markdown+multiline_tables+implicit_figures+link_attributes+raw_html -t html \
		--section-divs \
		--standalone \
		--shift-heading-level-by=1 \
		--template lib/templates/template.html \
		-o $@ $<

%.html: %.org lib/templates/template.html lib/css/base.css
	pandoc -f org -t html \
		--section-divs \
		--standalone \
		--shift-heading-level-by=1 \
		--lua-filter=lib/lua/restore-org-metadata.lua \
		--template lib/templates/template.html \
		-o $@ $<

atom.xml: feeds.yaml lib/templates/atom.xml
	pandoc -M updated="$$(date --iso-8601='seconds')"\
		--metadata-file=feeds.yaml \
		--template=lib/templates/atom.xml \
		-t html \
		-o atom.xml < /dev/null

rss.xml: feeds.yaml lib/templates/rss.xml
	pandoc -M updated="$$(date '+%a, %d %b %Y %T %z')"\
		--metadata-file=feeds.yaml \
		--template=lib/templates/rss.xml \
		-t html \
		-o rss.xml < /dev/null

cv/cv.pdf: cv/cv4pdf.md 
	pandoc -f markdown+multiline_tables \
		-t pdf \
		-o cv/cv.pdf \
		cv/cv4pdf.md 

build/%: %
	mkdir -p $(@D) 
	cp $< $@ 


clean:
	rm -r build/*
