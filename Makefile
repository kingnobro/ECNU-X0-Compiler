all: build remove

build:   compiler.l compiler.y
	lex compiler.l
	bison -d compiler.y
	cc -g -o compiler lex.yy.c compiler.tab.c -lm

remove:
	rm *.c *.h
	rm -rf compiler.dSYM

clean:
	rm compiler
	rm *.txt