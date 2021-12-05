%{
#include <stdio.h>
#include <string.h>
#include "x0yacc.tab.h"

void yyerror(char *);
int yywrap(void);

int line = 1;
int debugMode = 0;
%}

%%
[ \t]   { ; }
[\n]    { line += 1; }
[\r\n]  { line += 1; }
"char"  { 
    if(debugMode) printf("char\n");
    yylval.type = (char *)malloc(strlen(yytext) + 1);
    return CHARSYM;
}
"int"   { 
    if(debugMode) printf("int\n");
    yylval.type = (char *)malloc(strlen(yytext) + 1);
    return INTSYM;
}
"if"    { if(debugMode) printf("if\n"); return IFSYM; }
"else"  { if(debugMode) printf("else\n"); return ELSESYM; }
"main"  { if(debugMode) printf("main\n"); return MAINSYM; }
"read"  { if(debugMode) printf("read\n"); return READSYM; }
"while" { if(debugMode) printf("while\n"); return WHILESYM; }
"write" { if(debugMode) printf("write\n"); return WRITESYM; }
"+" { if(debugMode) printf("+\n"); return PLUS; }
"-" { if(debugMode) printf("-\n"); return MINUS; }
"*" { if(debugMode) printf("*\n"); return TIMES; }
"/" { if(debugMode) printf("/\n"); return DIVIDE; }
"(" { if(debugMode) printf("(\n"); return LPAREN; }
")" { if(debugMode) printf(")\n"); return RPAREN; }
"[" { if(debugMode) printf("[\n"); return LBRACKET; }
"]" { if(debugMode) printf("]\n"); return RBRACKET; }
"{" { if(debugMode) printf("{\n"); return LBRACE; }
"}" { if(debugMode) printf("}\n"); return RBRACE; }
"=" { if(debugMode) printf("=\n"); return BECOMES; }
"," { if(debugMode) printf(",\n"); return COMMA; }
";" { if(debugMode) printf(";\n"); return SEMICOLON; }
">" { if(debugMode) printf(">\n"); return GRT; }
"<" { if(debugMode) printf("<\n"); return LES; }
"<="    { if(debugMode) printf("<=\n"); return LEQ; }
">="    { if(debugMode) printf(">=\n"); return GEQ; }
"!="    { if(debugMode) printf("!=\n"); return NEQ; }
"=="    { if(debugMode) printf("==\n"); return EQL; }
[0-9]+  { 
    yylval.number = atoi(yytext);
    if(debugMode) printf("number\n");
    return NUMBER;
}
[A-Za-z]([A-Za-z]|[0-9])* { 
    yylval.ident = (char *)malloc(strlen(yytext) + 1);
    strcpy(yylval.ident, yytext);
    if(debugMode) printf("ident\n");
    return IDENT;
}
.   { yyerror("Unknow character!"); }
%%

void redirectInput(FILE *input) {
    yyin = input;
}

int yygetchar(void) {
    int ret;
    ret = getc(yyin);
    printf("%c", ret);
    return ret;
}

int yywrap(void) {
    return 1;
}