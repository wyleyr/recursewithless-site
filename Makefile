
build/lib: lib
	cp -r lib/css build/lib && \
	cp -r lib/js build/lib && \
	cp -r lib/img build/lib 

build/index.html: index.html
	cp index.html build

build/%.html: %.md lib/templates/template.html lib/css/base.css
	pandoc -f markdown+multiline_tables+implicit_figures+link_attributes -t html \
		--section-divs \
		--standalone \
		--template lib/templates/template.html \
		--css lib/css/base.css \
		-o $@ $<

build/cv.pdf: cv4pdf.md 
	pandoc -f markdown+multiline_tables \
		-t pdf \
		-o build/cv.pdf \
		cv4pdf.md 

build/emacs: emacs
	cp -r emacs build

all: build/index.html build/cv.html build/photos.html build/emacs.html build/emacs build/lib build/cv.pdf

preview: all
	xdg-open build/index.html

clean:
	rm -r build/*
