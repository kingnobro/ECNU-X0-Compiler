all: build remove

build:   compiler.l compiler.y
	lex compiler.l
	bison -d compiler.y
	cc `pkg-config --cflags gtk+-2.0` -g -o compiler lex.yy.c compiler.tab.c -lm `pkg-config --libs gtk+-2.0`

remove:
	rm *.c *.h
	rm -rf compiler.dSYM

clean:
	rm compiler