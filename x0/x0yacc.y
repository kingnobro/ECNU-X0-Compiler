%{
#include <stdio.h>
#include <stdlib.h>
#include <memory.h>
#include <string.h>

#define tableSize 100   // 符号表容量
#define maxLength 10    // 标识符的最大长度

extern int yyerror(char *);
extern int yylex(void);
extern void redirectInput(FILE *input);

// 符号表中的类型
enum object {
    variable,
};

// 符号表结构
struct tablestruct {
    char name[maxLength];   // 名字
    enum object kind;       // 类型(const, variable)
};
struct tablestruct table[tableSize];    // 符号表

int tail;   // 符号表当前尾指针
char id[maxLength];

FILE* fin;  // 输入源文件
FILE* fout; // 输出错误信息
char filename[maxLength];
int errorCount;
extern int line;

void enter(enum object k);
int position(char *s);
%}

%union {
    char *ident;
    int number;
}

%token CHARSYM INTSYM ELSESYM IFSYM MAINSYM READSYM WHILESYM WRITESYM
%token PLUS MINUS TIMES DIVIDE LPAREN RPAREN LBRACKET RBRACKET LBRACE RBRACE BECOMES COMMA SEMICOLON GRT LES LEQ GEQ NEQ EQL
%token <ident> IDENT
%token <number> NUMBER

%left    PLUS MINUS
%left    TIMES DIVIDE
%nonassoc LOWER_THAN_ELSE
%nonassoc ELSESYM

%%

program:
    MAINSYM LBRACE declaration_list statement_list RBRACE
    ;

declaration_list:
    declaration_list declaration_stat
    | declaration_stat
    ;

declaration_stat:
    type IDENT SEMICOLON
    | type IDENT LBRACKET NUMBER RBRACKET SEMICOLON
    ;

type:
    INTSYM
    | CHARSYM
    ;

var:
    IDENT
    | IDENT LBRACKET expression RBRACKET
    ;

statement_list:
    statement_list statement
    |
    statement
    ;

statement:
    if_stat
    | while_stat
    | read_stat
    | write_stat
    | compound_stat
    | expression_stat
    ;

if_stat:
    IFSYM LPAREN expression RPAREN statement %prec LOWER_THAN_ELSE
    | IFSYM LPAREN expression RPAREN statement ELSESYM statement
    ;

while_stat:
    WHILESYM LPAREN expression RPAREN statement
    ;

write_stat:
    WRITESYM expression SEMICOLON
    ;

read_stat:
    READSYM var SEMICOLON
    ;

compound_stat:
    LBRACE statement_list RBRACE
    ;

expression_stat:
    expression SEMICOLON
    | SEMICOLON
    ;

expression:
    var BECOMES expression
    | simple_expr
    ;

simple_expr:
    additive_expr
    | additive_expr GRT additive_expr
    | additive_expr LES additive_expr
    | additive_expr GEQ additive_expr
    | additive_expr LEQ additive_expr
    | additive_expr EQL additive_expr
    | additive_expr NEQ additive_expr
    ;

additive_expr:
    term
    | additive_expr PLUS term
    | additive_expr MINUS term
    ;

term:
    factor
    | term TIMES factor
    | term DIVIDE factor
    ;

factor:
    LPAREN expression RPAREN
    | var
    | NUMBER
    ;

%%

int yyerror(char *s) {
    errorCount += 1;
    printf("%s in line %d\n", s, line);
    fprintf(fout, "%s in line %d\n", s, line);
    return 0;
}

void enter(enum object k) {
    tail += 1;
    strcpy(table[tail].name, id);
    table[tail].kind = k;
}

int position(char *s) {
    int i;
    strcpy(table[0].name, s);
    i = tail;
    while (strcmp(table[i].name, s) != 0) {
        i -= 1;
    }
    return i;
}

int main() {
    printf("x0 filename: ");
    scanf("%s", filename);

    if ((fin = fopen(filename, "r")) == NULL) {
        printf("Can't open the input file!\n");
        exit(1);
    }
    if ((fout = fopen("foutput.txt", "w")) == NULL) {
        printf("Can't open the output file!\n");
        exit(1);
    }

    redirectInput(fin);
    tail = 0;
    errorCount = 0;
    yyparse();
    if (errorCount == 0) {
        printf("\n===Parsing Success===\n");
        fprintf(fout, "\n===Parsing Success===\n");
    } else {
        printf("%d errors in x0 program\n", errorCount);
        fprintf(fout, "%d errors in x0 program\n", errorCount);
    }
    fclose(fout);
    fclose(fin);
    return 0;
}