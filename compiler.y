%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>
#include <gtk/gtk.h>

#define MaxTableSize    100     // 符号表容量
#define MaxNameLength   20      // 标识符的最大长度
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
    x0_bool,
};

// 符号表中符号的构成
typedef struct _symbol {
    char name[MaxNameLength]; // 名字
    int type;                 // 符号类型(array, variable, procedure)
    int datatype;             // 数据类型(int, char, bool)
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
int variableCount;      // 变量个数, 用于符号表
int variableSize;       // 变量大小, 用于栈
bool is_char;
bool is_bool;
bool is_array_element;
bool is_write;
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
void fatal(char *s);
void display_table();
int positionOfSymbol(char *s);
extern void yyerror(char *);
extern int yylex(void);
extern void redirectInput(FILE *input);


// GUI
// ----------------------------------------
GtkWidget *window;
GtkWidget *x0code;
GtkWidget *pcode;
GtkWidget *output;
GtkWidget *symtable;

void import_onclick(GtkWidget *widget, gpointer data);
void import_openfile(GtkWidget* trigger, gint response_id, gpointer data);
void save_onclick(GtkWidget *widget, gpointer data);
void save_openfile(GtkWidget* trigger, gint response_id, gpointer data);
void run_onclick(GtkWidget *widget, gpointer data);
// ----------------------------------------
%}

%union {
    char *ident;
    int number;
}

%token CHARSYM BOOLSYM INTSYM ELSESYM IFSYM MAINSYM READSYM WHILESYM WRITESYM FORSYM TRUESYM FALSESYM
%token LPAREN RPAREN LBRACKET RBRACKET LBRACE RBRACE BECOMES COMMA SEMICOLON
%token SPLUS SMINUS PLUS MINUS TIMES DIVIDE AND OR NOT
%token GRT LES LEQ GEQ NEQ EQL MOD
%token <ident> IDENT
%token <number> NUMBER
%type <number> var code_address type else_stat

%left   PLUS MINUS
%left   TIMES DIVIDE MOD
%left   AND OR
%left   SPLUS SMINUS
%right  NOT
%nonassoc LOWER_THAN_ELSE
%nonassoc ELSESYM

%%

program:
    code_address
    {
        genCode(jmp, 0, 0);
    }
    MAINSYM
    {
        // 记录 main 函数的起始地址
        code[$1].a = codeTableTail;
    }
    LBRACE declaration_list
    {
        setReletiveAddress(variableCount);  // 写入符号表
        genCode(ini, 0, variableSize + 3);  // 栈分配空间
    }
    statement_list RBRACE
    {
        genCode(opr, 0, 0); // main 函数终止
    }
    ;

code_address:  // 记录下当前汇编代码地址, 用于计算跳转地址
    {
        $$ = codeTableTail;
    }
    ;

declaration_list:
    declaration_list declaration_stat
    | declaration_stat
    ;

declaration_stat:
    type IDENT SEMICOLON
    {
        // 基本变量
        variableCount += 1;
        variableSize += 1;
        strcpy(identifier, $2);
        addToTable(variable);
        if ($1 == 1) {
            symbolTable[symbolTableTail].datatype = x0_int;
        } else if ($1 == 2) {
            symbolTable[symbolTableTail].datatype = x0_char;
        } else {
            symbolTable[symbolTableTail].datatype = x0_bool;
        }
    }
    | type IDENT LBRACKET NUMBER RBRACKET SEMICOLON
    {
        // 数组变量
        variableCount += 1;
        variableSize += $4;
        strcpy(identifier, $2);
        addToTable(array);
        symbolTable[symbolTableTail].size = $4; // 记录数组元素个数
        if ($1 == 1) {
            symbolTable[symbolTableTail].datatype = x0_int;
        } else if ($1 == 2) {
            symbolTable[symbolTableTail].datatype = x0_char;
        } else {
            symbolTable[symbolTableTail].datatype = x0_bool;
        }
    }
    ;

type:
    INTSYM
    {
        $$ = 1;
    }
    | CHARSYM
    {
        $$ = 2;
    }
    | BOOLSYM
    {
        $$ = 3;
    }
    ;

var:
    IDENT
    {
        $$ = positionOfSymbol($1);
        if (symbolTable[$$].datatype == x0_char) {
            is_char = true;
            is_bool = false;
        } else if (symbolTable[$$].datatype == x0_bool) {
            is_char = false;
            is_bool = true;
        } else {
            is_char = is_bool = false;
        }
        is_array_element = false;
    }
    | IDENT LBRACKET expression RBRACKET
    {
        $$ = positionOfSymbol($1);
        if (symbolTable[$$].datatype == x0_char) {
            is_char = true;
            is_bool = false;
        } else if (symbolTable[$$].datatype == x0_bool) {
            is_char = false;
            is_bool = true;
        } else {
            is_char = is_bool = false;
        }
        is_array_element = true;

        genCode(lit, 0, symbolTable[$$].address);   // 把数组基址存入栈顶
        genCode(opr, 0, 2); // 基址+偏移量. 偏移量是由 expression 放入栈顶的
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
    IFSYM LPAREN expression RPAREN code_address
    {
        genCode(jpc, 0, 0);
    }
    statement else_stat
    {
        // 如果 if 条件不成立, 直接跳转
        code[$5].a = $8;
    }

else_stat:
    ELSESYM code_address
    {
        genCode(jmp, 0, 0);
    }
    statement
    {
        $$ = $2 + 1;    // 有 else 分支, 跳转到 else 的 statement
        code[$2].a = codeTableTail;
    }
    |
    {
        $$ = codeTableTail;
    }


while_stat:
    WHILESYM LPAREN code_address expression RPAREN code_address 
    {
        genCode(jpc, 0, 0);
    }
    statement
    {
        genCode(jmp, 0, $3);
        code[$6].a = codeTableTail;
    }
    ;

write_stat:
    WRITESYM 
    {
        is_write = true;
    }
    expression_stat
    ;

read_stat:
    READSYM var SEMICOLON
    {
        if (is_char) genCode(opr, 0, 20); // 读 char
        else genCode(opr, 0, 16);   // 读 int, bool

        if (is_array_element) genCode(opr, 0, 17); // 存到数组
        else genCode(sto, currentLevel - symbolTable[$2].level, symbolTable[$2].address);

        genCode(pop, 0, 1);
    }
    ;

compound_stat:
    LBRACE statement_list RBRACE
    ;

expression_stat:
    expression SEMICOLON
    {
        if (is_write)
        {
            if (is_char) genCode(opr, 0, 19);
            else if (is_bool) genCode(opr, 0, 22);
            else genCode(opr, 0, 14);

            genCode(opr, 0, 15);    // 换行符
            is_write = false;
        }
        genCode(pop, 0, 1); // 弹出 expression 的值
    }
    | SEMICOLON
    ;

expression:
    var BECOMES expression
    {
        if (is_array_element) genCode(opr, 0, 17);
        else genCode(sto, currentLevel - symbolTable[$1].level, symbolTable[$1].address);
    }
    | simple_expr
    ;

simple_expr:
    additive_expr
    | additive_expr GRT additive_expr
    {
        genCode(opr, 0, 12);
    }
    | additive_expr LES additive_expr
    {
        genCode(opr, 0, 10);
    }
    | additive_expr GEQ additive_expr
    {
        genCode(opr, 0, 11);
    }
    | additive_expr LEQ additive_expr
    {
        genCode(opr, 0, 13);
    }
    | additive_expr EQL additive_expr
    {
        genCode(opr, 0, 8);
    }
    | additive_expr NEQ additive_expr
    {
        genCode(opr, 0, 9);
    }
    | additive_expr AND additive_expr
    {
        genCode(opr, 0, 23);
    }
    | additive_expr OR additive_expr
    {
        genCode(opr, 0, 24);
    }
    ;

additive_expr:
    term
    | additive_expr PLUS term
    {
        genCode(opr, 0, 2);
    }
    | additive_expr MINUS term
    {
        genCode(opr, 0, 3);
    }
    | NOT additive_expr
    {
        genCode(opr, 0, 25);
    }
    ;

term:
    factor
    | term TIMES factor
    {
        genCode(opr, 0, 4);
    }
    | term DIVIDE factor
    {
        genCode(opr, 0, 5);
    }
    | term MOD factor
    {
        genCode(opr, 0, 21);
    }
    ;

factor:
    LPAREN expression RPAREN
    | var
    {
        if (is_array_element) genCode(opr, 0, 18);
        else genCode(lod, currentLevel - symbolTable[$1].level, symbolTable[$1].address);
    }
    | var SPLUS
    {
        if (!is_array_element) {
            genCode(lod, currentLevel - symbolTable[$1].level, symbolTable[$1].address);
            genCode(lod, currentLevel - symbolTable[$1].level, symbolTable[$1].address);
            genCode(lit, 0, 1);
            genCode(opr, 0, 2);
            genCode(sto, currentLevel - symbolTable[$1].level, symbolTable[$1].address);
            genCode(pop, 0, 1);
        } else {
            fatal("[SPLUS] on array element is not permitted");
        }
    }
    | var SMINUS
    {
        if (!is_array_element) {
            genCode(lod, currentLevel - symbolTable[$1].level, symbolTable[$1].address);
            genCode(lod, currentLevel - symbolTable[$1].level, symbolTable[$1].address);
            genCode(lit, 0, 1);
            genCode(opr, 0, 3);
            genCode(sto, currentLevel - symbolTable[$1].level, symbolTable[$1].address);
            genCode(pop, 0, 1);
        } else {
            fatal("[SPLUS] on array element is not permitted");
        }
    }
    | SPLUS var
    {
        if (!is_array_element) {
            genCode(lod, currentLevel - symbolTable[$2].level, symbolTable[$2].address);
            genCode(lit, 0, 1);
            genCode(opr, 0, 2);
            genCode(sto, currentLevel - symbolTable[$2].level, symbolTable[$2].address);
            genCode(pop, 0, 1);
            genCode(lod, currentLevel - symbolTable[$2].level, symbolTable[$2].address);
        } else {
            fatal("[SPLUS] on array element is not permitted");
        }
    }
    | SMINUS var
    {
        if (!is_array_element) {
            genCode(lod, currentLevel - symbolTable[$2].level, symbolTable[$2].address);
            genCode(lit, 0, 1);
            genCode(opr, 0, 3);
            genCode(sto, currentLevel - symbolTable[$2].level, symbolTable[$2].address);
            genCode(pop, 0, 1);
            genCode(lod, currentLevel - symbolTable[$2].level, symbolTable[$2].address);
        } else {
            fatal("[SPLUS] on array element is not permitted");
        }
    }
    | NUMBER
    {
        genCode(lit, 0, $1);
    }
    | TRUESYM
    {
        genCode(lit, 0, 1);
    }
    | FALSESYM
    {
        genCode(lit, 0, 0);
    }
    ;

%%

void yyerror(char *s) {
    errorNumber += 1;
    GtkWidget *dialog;
    dialog = gtk_message_dialog_new(NULL, GTK_DIALOG_DESTROY_WITH_PARENT, GTK_MESSAGE_ERROR,
                GTK_BUTTONS_OK, s);
    gtk_window_set_title(GTK_WINDOW(dialog), "Compiler Error");
    gtk_dialog_run(GTK_DIALOG(dialog));
    gtk_widget_destroy(dialog);
}

void fatal(char *s) {
    printf("Fatal error: %s\nAbort now!\n", s);
    exit(1);
}

void init() {
    codeTableTail = 0;
    procTableTail = 0;
    symbolTableTail = 0;
    variableCount = 0;
    currentLevel = 0;
    proctable[0] = 0;
    errorNumber = 0;
    is_char = false;
    is_array_element = false;
    is_bool = false;
    is_write = false;
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
        { "pop" },
    };
    for (int i = 0; i < codeTableTail; i++) {
        printf("%d %s %d %d\n", i, op_name[code[i].op], code[i].level_diff, code[i].a);
        fprintf(fcode, "%d %s %d %d\n", i, op_name[code[i].op], code[i].level_diff, code[i].a);
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
    switch (type) {
        case variable:
            symbolTable[symbolTableTail].level = currentLevel;
            symbolTable[symbolTableTail].size = 1;
            break;
        case array:
            symbolTable[symbolTableTail].level = currentLevel;
            break;
        case procedure:
            break;
    }
}

void display_table() {
    char map[][5] = {
        { "int" },
        { "char" },
        { "bool" },
    };
    printf("num\t name\t type\t\t level\t address\t size\n");
    fprintf(ftable, "num\t name\t type\t\t level\t address\t size\n");
    for (int i = 1; i <= symbolTableTail; i++) {   
        switch (symbolTable[i].type) {
            case variable:
                printf(
                    "%3d\t %s\t var:%s\t %2d\t %3d\t %3d\n",
                    i,
                    symbolTable[i].name,
                    map[symbolTable[i].datatype],
                    symbolTable[i].level,
                    symbolTable[i].address,
                    symbolTable[i].size
                );
                fprintf(
                    ftable,
                    "%3d\t %s\t var:%s\t %2d\t %3d\t %3d\n",
                    i,
                    symbolTable[i].name,
                    map[symbolTable[i].datatype],
                    symbolTable[i].level,
                    symbolTable[i].address,
                    symbolTable[i].size
                );
                break;
            case array:
                printf(
                    "%3d\t %s\t ary:%s\t %2d\t %3d\t %3d\n",
                    i,
                    symbolTable[i].name,
                    map[symbolTable[i].datatype],
                    symbolTable[i].level,
                    symbolTable[i].address,
                    symbolTable[i].size
                );
                fprintf(
                    ftable,
                    "%3d\t %s\t ary:%s\t %2d\t %3d\t %3d\n",
                    i,
                    symbolTable[i].name,
                    map[symbolTable[i].datatype],
                    symbolTable[i].level,
                    symbolTable[i].address,
                    symbolTable[i].size
                );
                break;

            case procedure:
                fatal("procedure not supported");
                break;
        }
    }
    printf("\n");
    fprintf(ftable, "\n");
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
 * 查找基址
 */
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
    fprintf(fresult,"Start X0\n");

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
                        fprintf(fresult, "%d", s[t]);
                        break;
                    case 15:    // 输出换行符
                        printf("\n");
                        fprintf(fresult, "\n");
                        break;
                    case 16:    // 读入一个输入置于栈顶
                        t = t + 1;
                        printf("?");
                        fprintf(fresult, "?");
                        scanf("%d", &(s[t]));
                        fprintf(fresult, "%d\n", s[t]);						
                        break;
                    case 17:    // 把栈顶的值存入存入数组
                        t = t - 1;
                        s[s[t]+1] = s[t+1];
                        break;
                    case 18:    // 读取数组的值
                        s[t] = s[s[t]+1];
                        break;
                    case 19:    // 输出栈顶的字符
                        printf("%c", s[t]);
                        fprintf(fresult, "%c", s[t]);
                        break;
                    case 20:    // 读入一个字符置于栈顶
                        t = t + 1;
                        printf("?");
                        fprintf(fresult, "?");
                        char c;
                        scanf("%c", &c);
                        fprintf(fresult, "%c\n", c);
                        s[t] = c;
                        break;
                    case 21:    // mod 运算符
                        t = t - 1;
                        s[t] = s[t] % s[t + 1];
                        break;
                    case 22:
                        if (s[t] != 0) {
                            printf("true");
                            fprintf(fresult, "true");
                        } else {
                            printf("false");
                            fprintf(fresult, "false");
                        }
                        break;
                    case 23:    // 与
                        t = t - 1;
                        s[t] = (s[t] && s[t + 1]);
                        break;
                    case 24:    // 或
                        t = t - 1;
                        s[t] = (s[t] || s[t + 1]);
                        break;
                    case 25:    // 非
                        s[t] = !s[t];
                        break;
                    default:
                        fatal("unrecognized opr");
                }
                break;
            case lod:	// 取相对当前过程的数据基地址为a的内存的值到栈顶
                t = t + 1;
                s[t] = s[base(i.level_diff, s, b) + i.a];	
                break;
            case sto:	// 栈顶的值存到相对当前过程的数据基地址为a的内存
                s[base(i.level_diff, s, b) + i.a] = s[t];
                // t = t - 1;  // 改为手动 pop
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
    fprintf(fresult,"End X0\n");
}

int main(int argc, char* argv[]) {
    // 指令结构
    const gchar* code_items[6] = {
        "op",
        "level_diff",
        "a",
    };
    // 符号表结构
    const gchar* symtable_items[9] = {
        "num",
        "name",
        "type",
        "level",
        "address",
        "size",
    };
    GtkWidget *table;

    // 分区标题
    GtkWidget *x0code_title;
    GtkWidget *code_title;
    GtkWidget *output_title;
    GtkWidget *symtable_title;

    // 操作按钮
    GtkWidget *import;
    GtkWidget *save;
    GtkWidget *run;

    // 对齐方式
    GtkWidget *halign;
    GtkWidget *halign2;
    GtkWidget *halign3;
    GtkWidget *halign4;

    // 滑块窗口
    GtkWidget *scrolled_window;
    GtkWidget *scrolled_window1;

    gtk_init(&argc, &argv);

    window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
    gtk_window_set_position(GTK_WINDOW(window), GTK_WIN_POS_CENTER);
    gtk_widget_set_size_request (window, 900, 600);
    gtk_window_set_resizable(GTK_WINDOW(window), TRUE);

    gtk_window_set_title(GTK_WINDOW(window), "X0 Compiler");

    gtk_container_set_border_width(GTK_CONTAINER(window), 15);

    table = gtk_table_new(16, 16, TRUE);
    gtk_table_set_row_spacings(GTK_TABLE(table), 5);
    gtk_table_set_col_spacings(GTK_TABLE(table), 5);

    scrolled_window = gtk_scrolled_window_new(NULL, NULL);
    scrolled_window1 = gtk_scrolled_window_new(NULL, NULL);

    x0code_title = gtk_label_new("X0 Code");
    halign = gtk_alignment_new(0, 0, 0, 0);
    gtk_container_add(GTK_CONTAINER(halign), x0code_title);
    gtk_table_attach(GTK_TABLE(table), halign, 0, 1, 0, 1, 
      GTK_FILL, GTK_FILL, 0, 0);

    x0code = gtk_text_view_new();
    gtk_text_view_set_editable(GTK_TEXT_VIEW(x0code), TRUE);
    gtk_text_view_set_cursor_visible(GTK_TEXT_VIEW(x0code), TRUE);
    gtk_table_attach(GTK_TABLE(table), x0code, 0, 9, 1, 9,
      GTK_FILL|GTK_EXPAND, GTK_FILL|GTK_EXPAND, 1, 1);
    

    code_title = gtk_label_new("P-code");
    halign2 = gtk_alignment_new(0, 0, 0, 0);
    gtk_container_add(GTK_CONTAINER(halign2), code_title);
    gtk_table_attach(GTK_TABLE(table), halign2, 9, 10, 0, 1, 
      GTK_FILL, GTK_FILL, 0, 0);

    pcode = gtk_clist_new_with_titles(3, code_items);
    gtk_scrolled_window_set_policy (GTK_SCROLLED_WINDOW(scrolled_window), GTK_POLICY_ALWAYS, GTK_POLICY_NEVER);
    gtk_container_add(GTK_CONTAINER(scrolled_window), pcode);
    gtk_table_attach(GTK_TABLE(table), scrolled_window, 9, 15, 1, 9,
      GTK_FILL|GTK_EXPAND, GTK_FILL|GTK_EXPAND, 1, 1);
    
    import = gtk_button_new_with_label("Import");
    gtk_widget_set_size_request(import, 50, 30);
    gtk_table_attach(GTK_TABLE(table), import, 15, 16, 1, 2, 
      GTK_FILL, GTK_SHRINK, 1, 1);
    g_signal_connect(G_OBJECT(import), "clicked", G_CALLBACK(import_onclick),NULL);

    save = gtk_button_new_with_label("Save");
    gtk_widget_set_size_request(save, 50, 30);
    gtk_table_attach(GTK_TABLE(table), save, 15, 16, 2, 3, 
      GTK_FILL, GTK_SHRINK, 1, 1);
    g_signal_connect(G_OBJECT(save), "clicked", G_CALLBACK(save_onclick),NULL);
    
    output_title = gtk_label_new("Output");
    halign3 = gtk_alignment_new(0, 0, 0, 0);
    gtk_container_add(GTK_CONTAINER(halign3), output_title);
    gtk_table_attach(GTK_TABLE(table), halign3, 0, 1, 9, 10, 
      GTK_FILL, GTK_FILL, 0, 0);

    output = gtk_text_view_new();
    gtk_text_view_set_editable(GTK_TEXT_VIEW(output), FALSE);
    gtk_text_view_set_cursor_visible(GTK_TEXT_VIEW(output), FALSE);
    gtk_table_attach(GTK_TABLE(table), output, 0, 9, 10, 15,
      GTK_FILL|GTK_EXPAND, GTK_FILL|GTK_EXPAND, 1, 1);

    symtable_title = gtk_label_new("Symbol Table");
    halign4 = gtk_alignment_new(0, 0, 0, 0);
    gtk_container_add(GTK_CONTAINER(halign4), symtable_title);
    gtk_table_attach(GTK_TABLE(table), halign4, 9, 10, 9, 10, 
      GTK_FILL, GTK_FILL, 0, 0);

    symtable = gtk_clist_new_with_titles(6, symtable_items);
    gtk_scrolled_window_set_policy (GTK_SCROLLED_WINDOW(scrolled_window1), GTK_POLICY_ALWAYS, GTK_POLICY_NEVER);
    gtk_container_add(GTK_CONTAINER(scrolled_window1), symtable);
    gtk_table_attach(GTK_TABLE(table), scrolled_window1, 9, 15, 10, 15,
      GTK_FILL|GTK_EXPAND, GTK_FILL|GTK_EXPAND, 1, 1);
    
    run = gtk_button_new_with_label("Run");
    gtk_widget_set_size_request(run, 50, 30);
    gtk_table_attach(GTK_TABLE(table), run, 0, 1, 15, 16, 
      GTK_FILL, GTK_SHRINK, 1, 1);
    g_signal_connect(G_OBJECT(run), "clicked", G_CALLBACK(run_onclick),NULL);

    gtk_container_add(GTK_CONTAINER(window), table);

    g_signal_connect_swapped(G_OBJECT(window), "destroy",
        G_CALLBACK(gtk_main_quit), G_OBJECT(window));

    gtk_widget_show_all(window);
    gtk_main();

    // const char *testfilename = "test/bool.x0";
    // printf("x0 filename: %s\n", testfilename);
    // if ((fin = fopen(testfilename, "r")) == NULL) {
    //     fatal("Can't open the input file!");
    // }
    
    // printf("x0 filename: ");
    // scanf("%s", filename);

    // if ((fin = fopen(filename, "r")) == NULL) {
    //     fatal("Can't open the input file!");
    // }
    // if ((fout = fopen("foutput.txt", "w")) == NULL) {
    //     fatal("Can't open the foutput.txt file!");
    // }
    // if ((ftable = fopen("ftable.txt", "w")) == NULL) {
    //     fatal("Can't open the ftable.txt file!");
    // }

    // redirectInput(fin);
    // init();
    // yyparse();
    // if (errorNumber == 0) {
    //     printf("\n===Parsing Success===\n");
    //     fprintf(fout, "\n===Parsing Success===\n");
    //     if ((fcode = fopen("fcode.txt", "w")) == NULL) {
    //         fatal("Can't open the fcode.txt file!");
    //     }
    //     if ((fresult = fopen("fresult.txt", "w")) == NULL) {
    //         fatal("Can't open the fresult.txt file!");
    //     }

    //     display_table();

    //     listAllCode();      // 输出所有汇编指令
    //     fclose(fcode);

    //     interpret();    // 调用解释执行程序
    //     fclose(fresult);
    // } else {
    //     printf("%d errors in x0 program\n", errorNumber);
    //     fprintf(fout, "%d errors in x0 program\n", errorNumber);
    // }

    // fclose(fout);
    // fclose(fin);
    // fclose(ftable);
    return 0;
}

void import_onclick(GtkWidget *widget, gpointer data)
{
    
}


void import_openfile(GtkWidget* trigger, gint response_id, gpointer data)
{

}

void save_onclick(GtkWidget *widget, gpointer data)
{
   
}

void save_openfile(GtkWidget* trigger, gint response_id, gpointer data)
{

}

void run_onclick(GtkWidget *widget, gpointer data)
{

}