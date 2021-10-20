%{
#include "stdio.h"
#include "string.h"

int line=1;
int yywrap(void);
%}

%%
[ \t]		{;}
[\n]		{line++;}
"begin"		{printf("BEGINSYM\n");}
"call"		{printf("CALLSYM\n");}
"const"		{printf("CONSTSYM\n");}
"do"		{printf("DOSYM\n");}
"end"		{printf("ENDSYM\n");}
"if"		{printf("IFSYM\n");}
"odd"		{printf("ODDSYM\n");}
"procedure"	{printf("PROCSYM\n");}
"read"		{printf("READSYM\n");}
"then"		{printf("THENSYM\n");}
"var"		{printf("VARSYM\n");}
"while"		{printf("WHILESYM\n");}
"write"		{printf("WRITESYM\n");}
[A-Za-z]([A-Za-z]|[0-9])*	{printf("IDENT\n");}

[0-9]+	{printf("NUMBER\n");}
":="	{printf("BECOMES\n");}
"<"		{printf("LSS\n");}
"<="	{printf("LEQ\n");}
">"		{printf("GTR\n");}
">="	{printf("GEQ\n");}
"+"		{printf("PLUS\n");}
"-"		{printf("MINUS\n");}
"*"		{printf("TIMES\n");}
"/"		{printf("SLASH\n");}
"("		{printf("LPAREN\n");}
")"		{printf("RPAREN\n");}
"="		{printf("EQL\n");}
","		{printf("COMMA\n");}
"."		{printf("PERIOD\n");}
"#"		{printf("NEQ\n");}
";"		{printf("SEMICOLON\n");}
.		{printf("Unknown character!");}

%%

int yywrap(void)
{
	return 1;
}

int main(int argc, char *argv[]) {
	yyin = fopen(argv[1], "r");
	yylex();
	fclose(yyin);
}