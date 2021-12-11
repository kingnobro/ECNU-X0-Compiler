all: build

build:   x0lex.l x0yacc.y
	lex x0lex.l
	bison -d x0yacc.y
	cc -g -o compiler lex.yy.c x0yacc.tab.c -lm

clean:  
	rm *.c *.h *.txt compiler