all: prog clean

prog:   pl0lex.l pl0yacc.y
	lex pl0lex.l
	bison -d pl0yacc.y
	cc -g -o compiler  lex.yy.c pl0yacc.tab.c -lm

clean:  
	rm lex.yy.c pl0yacc.tab.c pl0yacc.tab.h