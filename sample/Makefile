all: clean
	../markdown2impress.pl index.md --height=1000
	test -f my.css && cat my.css >> css/impress.css

clean:
	rm -rf index.html *.js js/ css/
