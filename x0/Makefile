all: prog clean

prog:   x0lex.l x0yacc.y
	lex x0lex.l
	bison -d x0yacc.y
	cc -g -o out lex.yy.c x0yacc.tab.c -lm

clean:  
	rm lex.yy.c x0yacc.tab.c x0yacc.tab.h out