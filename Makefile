
build/lib: lib
	cp -r lib build

build/index.html: index.html
	cp index.html build

build/cv.html: cv.md
	pandoc -f markdown -t html -o build/cv.html \
		--section-divs \
		--standalone \
		--template lib/templates/template.html \
		--css lib/css/base.css \
		cv.md

all: build/index.html build/cv.html build/lib
