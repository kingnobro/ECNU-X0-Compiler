%{
#include <stdio.h>
#include <stdlib.h>
#include <memory.h>
#include <string.h>

#define MaxTableSize 100    // 符号表容量
#define MaxNameLength 10    // 标识符的最大长度

// 符号表中符号的类型
enum {
    variable = 0,
    array,
};

// 符号表中符号的构成
typedef struct _symbol {
    char symbolName[MaxNameLength]; // 名字
    int symbolType; // 类型(const, variable)
} symbol;

// 符号表
symbol symbolTable[MaxTableSize];

// 符号表当前尾指针
int tail;

// 打印错误信息
int errorNumber;
extern int line;

// 输入输出文件
FILE* fin;
FILE* fout;
char filename[MaxNameLength];

char identifier[MaxNameLength];

void addToTable(int symbolType);
int positionOfSymbol(char *s);
extern int yyerror(char *);
extern int yylex(void);
extern void redirectInput(FILE *input);
%}

%union {
    char *ident;
    char *type;
    int number;
}

%token CHARSYM INTSYM ELSESYM IFSYM MAINSYM READSYM WHILESYM WRITESYM
%token PLUS MINUS TIMES DIVIDE LPAREN RPAREN LBRACKET RBRACKET LBRACE RBRACE BECOMES COMMA SEMICOLON GRT LES LEQ GEQ NEQ EQL
%token <ident> IDENT
%token <number> NUMBER
%type <number> var

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
    {
        strcpy(identifier, $2);
        addToTable(variable);
    }
    | type IDENT LBRACKET NUMBER RBRACKET SEMICOLON
    {
        strcpy(identifier, $2);
        addToTable(array);
    }
    ;

type:
    INTSYM
    | CHARSYM
    ;

var:
    IDENT
    {
        $$ = positionOfSymbol($1);
    }
    | IDENT LBRACKET expression RBRACKET
    {
        $$ = positionOfSymbol($1);
    }
    ;

statement_list:
    statement_list statement
    | statement
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
    {
        printf("%d\n", $1);
    }
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
    errorNumber += 1;
    printf("%s in line %d\n", s, line);
    fprintf(fout, "%s in line %d\n", s, line);
    return 0;
}

/*
 * symbolTable[0] 留空, 符号从 1 开始存储
 */
void addToTable(int symbolType) {
    tail += 1;
    strcpy(symbolTable[tail].symbolName, identifier);
    symbolTable[tail].symbolType = symbolType;
}

/*
 * 按 name 查找 symbol 的下标, 如果不存在返回 0
 */
int positionOfSymbol(char *name) {
    int i = tail;
    strcpy(symbolTable[0].symbolName, name);
    while (strcmp(symbolTable[i].symbolName, name) != 0) {
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
    errorNumber = 0;
    yyparse();
    if (errorNumber == 0) {
        printf("\n===Parsing Success===\n");
        fprintf(fout, "\n===Parsing Success===\n");
    } else {
        printf("%d errors in x0 program\n", errorNumber);
        fprintf(fout, "%d errors in x0 program\n", errorNumber);
    }
    fclose(fout);
    fclose(fin);
    return 0;
}