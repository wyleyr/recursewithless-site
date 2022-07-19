
build/lib: lib/css/base.css lib/js/tui.js lib/img/selfportrait.png
	mkdir -p build/lib/css build/lib/js build/lib/img && \
	cp lib/css/base.css build/lib/css && \
	cp lib/js/tui.js build/lib/js && \
	cp lib/img/selfportrait.png build/lib/img

build/index.html: index.html
	cp index.html build

build/%.html: %.md lib/templates/template.html lib/css/base.css
	pandoc -f markdown+multiline_tables -t html \
		--section-divs \
		--standalone \
		--template lib/templates/template.html \
		--css lib/css/base.css \
		-o $@ $<

all: build/index.html build/cv.html build/lib

preview: all
	xdg-open build/index.html

clean:
	rm -r build/*
