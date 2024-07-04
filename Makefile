all: 	build/index.html \
	$(addprefix build/, $(wildcard lib/css/*.css)) \
	$(addprefix build/, $(wildcard lib/js/*.js)) \
	$(addprefix build/, $(wildcard lib/img/*)) \
	build/cv/index.html \
	build/cv/cv.pdf \
	build/photos/index.html \
	$(addprefix build/, $(wildcard photos/*.jpg)) \
	build/projects/index.html \
	build/projects/chairs-restoration.html \
	$(addprefix build/, $(wildcard projects/img/chairs/*)) \
	build/emacs/index.html \
	$(addprefix build/, $(wildcard emacs/*.org))

%.html: %.md lib/templates/template.html lib/css/base.css
	pandoc -f markdown+multiline_tables+implicit_figures+link_attributes+raw_html -t html \
		--section-divs \
		--standalone \
		--template lib/templates/template.html \
		-o $@ $<

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
