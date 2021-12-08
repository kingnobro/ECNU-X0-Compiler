%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>

#define MaxTableSize    100     // 符号表容量
#define MaxNameLength   10      // 标识符的最大长度
#define MaxAddress      2028    // 地址上界
#define MaxLevel        3       // 最大允许过程嵌套声明层数
#define MaxInstrNumber  200     // 最多的虚拟机代码数
#define StackSize       500     // 栈的容量

// 符号表中符号的类型
enum {
    variable,
    array,
    procedure,
};

// 符号表中符号的数据类型
enum {
    x0_int,
    x0_char,
};

// 符号表中符号的构成
typedef struct _symbol {
    char name[MaxNameLength]; // 名字
    int type;                 // 符号类型(array, variable)
    int datatype;             // 数据类型(int, char)
    int level;                // 所在层次
    int address;              // 地址
    int size;                 // 需要分配的数据区空间, 仅 procedure 使用
} Symbol;

// 符号表
Symbol symbolTable[MaxTableSize];

// 虚拟机代码指令
enum {
    lit,    opr,    lod,
    sto,    cal,    ini,
    jmp,    jpc,
};

// 虚拟机代码结构
typedef struct _instruction {
    int op;         // 操作码
    int level_diff; // 引用层和声明层的层次差
    int a;          // todo: what's a means?
} Instruction;

// 存放虚拟机代码的数组
Instruction code[MaxInstrNumber];

int symbolTableTail;    // 符号表当前尾指针
int codeTableTail;      // 虚拟机代码指针
int procTableTail;      // 嵌套过程索引表 proctable 的指针
int currentLevel;       // 层次记录
bool listSwitch;        // 是否显示虚拟机代码
bool tableSwitch;       // 是否显示符号表
int proctable[3];       // 嵌套过程索引表, 最多嵌套三层
char identifier[MaxNameLength];

FILE* fin;      // 输入源文件
FILE* fout;     // 输出错误信息
FILE* ftable;   // 输出符号表
FILE* fcode;    // 输出虚拟机代码
FILE* fresult;  // 输出执行结果
char filename[MaxNameLength];
int errorNumber;    // 打印错误信息
extern int line;

void init();
void addToTable(int type);
void listAllCode();
void genCode(int op, int level_diff, int a);
void setReletiveAddress(int localVariablCount);
void interpret();
int positionOfSymbol(char *s);
extern int yyerror(char *);
extern int yylex(void);
extern void redirectInput(FILE *input);
%}

%union {
    char *ident;
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

void init() {
    codeTableTail = 0;
    procTableTail = 0;
    symbolTableTail = 0;
    currentLevel = 0;
    proctable[0] = 0;
    errorNumber = 0;
}

void setReletiveAddress(int localVariablCount) {
    int n = localVariablCount;
    for (int i = 1; i <= n; i += 1) {
        symbolTable[symbolTableTail - i + 1].address = n - i + 3;
    }
}

/*
 * 输出所有目标代码
 */
void listAllCode() {
    char op_name[][5] = {
        { "lit" },
        { "opr" },
        { "lod" },
        { "sto" },
        { "cal" },
        { "ini" },
        { "jmp" },
        { "jpc" },
    };
    if (listSwitch) {
        for (int i = 0; i < codeTableTail; i++) {
            printf("%d %s %d %d\n", i, op_name[code[i].op], code[i].level_diff, code[i].a);
            fprintf(fcode, "%d %s %d %d\n", i, op_name[code[i].op], code[i].level_diff, code[i].a);
        }
    }
}

void genCode(int op, int level_diff, int a) {
    // 生成的虚拟机代码程序过长
    if (codeTableTail >= MaxInstrNumber) {
        printf("Program is too long!\n");
        exit(1);
    }
    // 地址偏移越界
    if (a >= MaxAddress) {
        printf("Displacement address is too big!\n");
        exit(1);
    }
    code[codeTableTail].op = op;
    code[codeTableTail].level_diff = level_diff;
    code[codeTableTail].a = a;
    codeTableTail += 1;
}

/*
 * symbolTable[0] 留空, 符号从 1 开始存储
 */
void addToTable(int type) {
    symbolTableTail += 1;
    strcpy(symbolTable[symbolTableTail].name, identifier);
    symbolTable[symbolTableTail].type = type;
    symbolTable[symbolTableTail].level = currentLevel;
}

/*
 * 按 name 查找 symbol 的下标, 如果不存在返回 0
 */
int positionOfSymbol(char *name) {
    int i = symbolTableTail;
    strcpy(symbolTable[0].name, name);
    while (strcmp(symbolTable[i].name, name) != 0) {
        i -= 1;
    }
    return i;
}

/*
 * 虚拟机解释程序
 */
void interpret() {

}

int main() {
    printf("x0 filename: ");
    scanf("%s", filename);

    if ((fin = fopen(filename, "r")) == NULL) {
        printf("Can't open the input file!\n");
        exit(1);
    }
    if ((fout = fopen("foutput.txt", "w")) == NULL) {
        printf("Can't open the foutput.txt file!\n");
        exit(1);
    }
    if ((fout = fopen("ftable.txt", "w")) == NULL) {
        printf("Can't open the ftable.txt file!\n");
        exit(1);
    }

    // 是否输出虚拟机代码
    printf("List object codes?(Y/N)");
    scanf("%s", filename);
    listSwitch = (filename[0]=='y' || filename[0]=='Y');

    // 是否输出符号表
    printf("List symbol table?(Y/N)");
    scanf("%s", filename);
    tableSwitch = (filename[0]=='y' || filename[0]=='Y');

    redirectInput(fin);
    init();
    yyparse();
    if (errorNumber == 0) {
        printf("\n===Parsing Success===\n");
        fprintf(fout, "\n===Parsing Success===\n");
        if ((fcode = fopen("fcode.txt", "w")) == NULL) {
            printf("Can't open the fcode.txt file!\n");
            exit(1);
        }
        if ((fresult = fopen("fresult.txt", "w")) == NULL) {
            printf("Can't open the fresult.txt file!\n");
            exit(1);
        }

        listAllCode();      // 输出所有汇编指令
        fclose(fcode);

        // interpret();    // 调用解释执行程序
        fclose(fresult);
    } else {
        printf("%d errors in x0 program\n", errorNumber);
        fprintf(fout, "%d errors in x0 program\n", errorNumber);
    }

    fclose(fout);
    fclose(fin);
    fclose(ftable);
    return 0;
}