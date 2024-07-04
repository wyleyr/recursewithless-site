all: 	build/index.html \
	$(addprefix build/, $(wildcard lib/css/*.css)) \
	$(addprefix build/, $(wildcard lib/js/*.js)) \
	$(addprefix build/, $(wildcard lib/img/*)) \
	build/cv.html \
	build/photos.html \
	build/projects/index.html \
	build/projects/chairs-restoration.html \
	$(addprefix build/, $(wildcard projects/img/chairs/*)) \
	build/emacs.html \
	build/emacs/* 
# 	build/cv.pdf # TODO: doesn't build yet on ohm...font issue

%.html: %.md lib/templates/template.html lib/css/base.css
	pandoc -f markdown+multiline_tables+implicit_figures+link_attributes+raw_html -t html \
		--section-divs \
		--standalone \
		--template lib/templates/template.html \
		-o $@ $<

cv.pdf: cv4pdf.md 
	pandoc -f markdown+multiline_tables \
		-t pdf \
		-o cv.pdf \
		cv4pdf.md 

build/%: %
	mkdir -p $(@D) 
	cp $< $@ 


clean:
	rm -r build/*
