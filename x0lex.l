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
"char"  { return CHARSYM; }
"bool"  { return BOOLSYM; }
"for"   { return FORSYM; }
"int"   { return INTSYM; }
"if"    { return IFSYM; }
"else"  { return ELSESYM; }
"main"  { return MAINSYM; }
"read"  { return READSYM; }
"true"  { return TRUESYM; }
"false" { return FALSESYM; }
"while" { return WHILESYM; }
"write" { return WRITESYM; }
"<="    { return LEQ; }
">="    { return GEQ; }
"!="    { return NEQ; }
"=="    { return EQL; }
"++"    { return SPLUS; }
"--"    { return SMINUS; }
"&&"    { return AND; }
"||"    { return OR; }
"!"     { return NOT; }
"+"     { return PLUS; }
"-"     { return MINUS; }
"*"     { return TIMES; }
"/"     { return DIVIDE; }
"("     { return LPAREN; }
")"     { return RPAREN; }
"["     { return LBRACKET; }
"]"     { return RBRACKET; }
"{"     { return LBRACE; }
"}"     { return RBRACE; }
"="     { return BECOMES; }
","     { return COMMA; }
";"     { return SEMICOLON; }
">"     { return GRT; }
"<"     { return LES; }
"%"     { return MOD; }
[0-9]+  { 
    yylval.number = atoi(yytext);
    return NUMBER;
}
[A-Za-z]([A-Za-z]|[0-9])* { 
    yylval.ident = (char *)malloc(strlen(yytext) + 1);
    strcpy(yylval.ident, yytext);
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