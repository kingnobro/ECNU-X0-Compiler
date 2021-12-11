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
    jmp,    jpc,    pop,
};

// 虚拟机代码结构
typedef struct _instruction {
    int op;         // 操作码
    int level_diff; // 引用层和声明层的层次差
    int a;          // 根据操作码的不同, 有不同的含义
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


int base(int level_diff, int* stack, int base)
{
    int b = base;
    while (level_diff > 0) {
        b = stack[b];
        level_diff -= 1;
    }
    return b;
}

/*
 * 虚拟机解释程序
 */
void interpret()
{
    int p = 0;          // 指令指针
    int b = 1;          // 指令基址
    int t = 0;          // 栈顶指针
    Instruction i;      // 存放当前指令
    int s[StackSize];   // 栈

    printf("Start X0\n");
    fprintf(fout,"Start X0\n");

    s[0] = 0; //s[0]不用
    s[1] = 0; //主程序的三个联系单元均置为0
    s[2] = 0;
    s[3] = 0;
    do {
        i = code[p];	// 读当前指令
        p = p + 1;      
        switch (i.op)
        {
            case pop:   // 弹出栈顶元素
                t = t - i.a;
                break;
            case lit:	// 将常量a的值取到栈顶
                t = t + 1;
                s[t] = i.a;				
                break;
            case opr:	// 数学、逻辑运算
                switch (i.a)
                {
                    case 0:  // 函数调用结束后返回
                        t = b - 1;
                        p = s[t + 3];
                        b = s[t + 2];
                        break;
                    case 1: // 栈顶元素取反
                        s[t] = - s[t];
                        break;
                    case 2: // 次栈顶项加上栈顶项，退两个栈元素，相加值进栈
                        t = t - 1;
                        s[t] = s[t] + s[t + 1];
                        break;
                    case 3: // 次栈顶项减去栈顶项
                        t = t - 1;
                        s[t] = s[t] - s[t + 1];
                        break;
                    case 4: // 次栈顶项乘以栈顶项
                        t = t - 1;
                        s[t] = s[t] * s[t + 1];
                        break;
                    case 5: // 次栈顶项除以栈顶项
                        t = t - 1;
                        s[t] = s[t] / s[t + 1];
                        break;
                    case 6: // 栈顶元素的奇偶判断
                        s[t] = s[t] % 2;
                        break;
                    case 8: // 次栈顶项与栈顶项是否相等
                        t = t - 1;
                        s[t] = (s[t] == s[t + 1]);
                        break;
                    case 9: // 次栈顶项与栈顶项是否不等
                        t = t - 1;
                        s[t] = (s[t] != s[t + 1]);
                        break;
                    case 10:    // 次栈顶项是否小于栈顶项
                        t = t - 1;
                        s[t] = (s[t] < s[t + 1]);
                        break;
                    case 11:    // 次栈顶项是否大于等于栈顶项
                        t = t - 1;
                        s[t] = (s[t] >= s[t + 1]);
                        break;
                    case 12:    // 次栈顶项是否大于栈顶项
                        t = t - 1;
                        s[t] = (s[t] > s[t + 1]);
                        break;
                    case 13:    // 次栈顶项是否小于等于栈顶项
                        t = t - 1;
                        s[t] = (s[t] <= s[t + 1]);
                        break;
                    case 14:    // 栈顶值输出
                        printf("%d", s[t]);
                        fprintf(fout, "%d", s[t]);
                        break;
                    case 15:    // 输出换行符
                        printf("\n");
                        fprintf(fout,"\n");
                        break;
                    case 16:    // 读入一个输入置于栈顶
                        t = t + 1;
                        printf("?");
                        fprintf(fout, "?");
                        scanf("%d", &(s[t]));
                        fprintf(fout, "%d\n", s[t]);						
                        break;
                    case 17:    // 把栈顶的值存入存入数组
                        t = t - 1;
                        s[s[t]+1] = s[t+1];
                    case 18:    // 读取数组的值
                        s[t] = s[s[t]+1];
                    case 19:    // 输出栈顶的字符
                        printf("%c", s[t]);
                        fprintf(fout, "%c", s[t]);
                        break;
                    case 20:    // 读入一个字符置于栈顶
                        t = t + 1;
                        printf("?");
                        fprintf(fout, "?");
                        scanf("%d", &(s[t]));
                        fprintf(fout, "%c\n", s[t]);						
                        break;
                    case 21:    // mod 运算符
                        t = t - 1;
                        s[t] = s[t] % s[t + 1];
                        break;
                    default:
                        yyerror("unrecognized opr");
                }
                break;
            case lod:	// 取相对当前过程的数据基地址为a的内存的值到栈顶
                t = t + 1;
                s[t] = s[i.a + 1];	
                break;
            case sto:	// 栈顶的值存到相对当前过程的数据基地址为a的内存
                s[1 + i.a] = s[t];
                break;
            case cal:	// 调用子过程
                s[t + 1] = base(i.level_diff, s, b);	// 将父过程基地址入栈，即建立静态链
                s[t + 2] = b;	// 将本过程基地址入栈，即建立动态链
                s[t + 3] = p;	// 将当前指令指针入栈，即保存返回地址
                b = t + 1;	// 改变基地址指针值为新过程的基地址
                p = i.a;	// 跳转
                break;
            case ini:	// 在数据栈中为被调用的过程开辟a个单元的数据区
                t = t + i.a;	
                break;
            case jmp:	// 直接跳转
                p = i.a;
                break;
            case jpc:	// 条件跳转
                if (s[t] == 0) p = i.a;
                t = t - 1;
                break;
        }
    } while (p != 0);
    printf("End X0\n");
    fprintf(fout,"End X0\n");
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