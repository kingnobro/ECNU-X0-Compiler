#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define bool int
#define true 1
#define false 0

#define norw 8        /* 保留字个数 */
#define txmax 100     /* 符号表容量 */
#define nmax 14       /* 数字的最大位数 */
#define al 10         /* 标识符的最大长度 */

#define ENUM_SYMBOL(x)   case x: return(#x);

/*
 * 符号
 * 
 * ident: 标识符
 * becomes: 赋值
 * brace: {}
 * bracket: []
 * paren: ()
 */
enum symbol {
    /* 23 */
    ident,      number,     plus,       minus,      times,
    nul,        divide,     eql,        neq,        lss,
    leq,        gtr,        geq,        lparen,     rparen,
    comma,      semicolon,  lbracket,   rbracket,   lbrace,
    rbrace,     becomes,	comment,
    /* 保留字 8 */
    ifsym,      elsesym,    whilesym,   writesym,   readsym,
    mainsym,    intsym,     charsym,
};
#define symnum 31

/* 符号表中的类型 */
enum object {
    constant,
    variable,
};

char ch;            				/* 存放当前读取的字符，getch 使用 */
enum symbol sym;    				/* 当前的符号 */
char identifier[al+1];      		/* 当前ident，多出的一个字节用于存放0 */
int num;            				/* 当前number */
int currentPosition, lastPosition;  /* getch使用的计数器，currentPosition表示当前字符(ch)的位置 */
char line[81];      				/* 读取行缓冲区 */
char a[al+1];       				/* 临时符号，多出的一个字节用于存放0 */
char word[norw][al];        		/* 保留字 */
enum symbol wsym[norw];     		/* 保留字对应的符号值 */
enum symbol ssym[256];      		/* 单字符的符号值 */
int statementLevel = 0;				/* 记录 {} 的嵌套层次数 */
bool commentArea = false;			/* 记录注释的区域 */

// -------------
// debug 用
bool finished = false;
// -------------

/* 符号表结构 */
struct tablestruct {
    char name[al];	    /* 名字 */
    enum object kind;	/* 类型：const，var或procedure */
};

struct tablestruct table[txmax]; /* 符号表 */

FILE* fin;      /* 输入源文件 */
FILE* foutput;  /* 输出文件及出错示意（如有错） */
char filename[al];

void error(int n); 
void getsym();
void getch();
void init();

/* 打印 type 对应的字符串, debug 用 */
static inline const char *symbol_string(enum symbol type)
{
    switch (type)
    {
        ENUM_SYMBOL(ident)
        ENUM_SYMBOL(number)
        ENUM_SYMBOL(plus)
        ENUM_SYMBOL(minus)
        ENUM_SYMBOL(times)
        ENUM_SYMBOL(nul)
        ENUM_SYMBOL(divide)
        ENUM_SYMBOL(eql)
        ENUM_SYMBOL(neq)
        ENUM_SYMBOL(lss)
        ENUM_SYMBOL(leq)
        ENUM_SYMBOL(gtr)
        ENUM_SYMBOL(geq)
        ENUM_SYMBOL(lparen)
        ENUM_SYMBOL(rparen)
        ENUM_SYMBOL(comma)
        ENUM_SYMBOL(semicolon)
        ENUM_SYMBOL(lbracket)
        ENUM_SYMBOL(rbracket)
        ENUM_SYMBOL(lbrace)
        ENUM_SYMBOL(rbrace)
        ENUM_SYMBOL(becomes)
        ENUM_SYMBOL(ifsym)
        ENUM_SYMBOL(elsesym)
        ENUM_SYMBOL(whilesym)
        ENUM_SYMBOL(writesym)
        ENUM_SYMBOL(readsym)
        ENUM_SYMBOL(mainsym)
        ENUM_SYMBOL(intsym)
        ENUM_SYMBOL(charsym)
        ENUM_SYMBOL(comment)
    }
    return "Unsupported symbol";
}

/* 主程序开始 */
int main() {
    printf("Input x0 file: ");
    scanf("%s", filename);		/* 输入文件名 */

    if ((fin = fopen(filename, "r")) == NULL) {
        printf("Can't open the input file!\n");
        exit(1);
    }

    ch = fgetc(fin);
    /* 文件为空 */
    if (ch == EOF) {
        printf("The input file is empty!\n");
        fclose(fin);
        exit(1);
    }
    /* 将指针重置到起始位置 */
    rewind(fin);

    if ((foutput = fopen("foutput.txt", "w")) == NULL) {
        printf("Can't open the output file!\n");
        exit(1);
    }

    init();		/* 初始化 */	
    currentPosition = lastPosition = 0;
    ch = ' ';

    while (!finished)  {
        getsym();
        printf("%s\n", symbol_string(sym));
    }

    return 0;
}

/*
 * 初始化 
 */
void init()
{
    int i;

    /* 设置单字符符号 */
    for (i=0; i<=255; i++) {
        ssym[i] = nul;
    }
    ssym['+'] = plus;
    ssym['-'] = minus;
    ssym['*'] = times;
    ssym['/'] = divide;
    ssym['('] = lparen;
    ssym[')'] = rparen;
    ssym['['] = lbracket;
    ssym[']'] = rbracket;
    ssym['{'] = lbrace;
    ssym['}'] = rbrace;
    ssym['='] = becomes;
    ssym[','] = comma;
    ssym[';'] = semicolon;

    /* 设置保留字名字,按照字母顺序，便于二分查找 */
    strcpy(&(word[0][0]), "char");
    strcpy(&(word[1][0]), "else");
    strcpy(&(word[2][0]), "if");
    strcpy(&(word[3][0]), "int");
    strcpy(&(word[4][0]), "main");
    strcpy(&(word[5][0]), "read");
    strcpy(&(word[6][0]), "while");
    strcpy(&(word[7][0]), "write");

    /* 设置保留字符号 */
    wsym[0] = charsym;	
    wsym[1] = elsesym;
    wsym[2] = ifsym;
    wsym[3] = intsym;
    wsym[4] = mainsym;
    wsym[5] = readsym;
    wsym[6] = whilesym;
    wsym[7] = writesym;  
}

/* 
 *	出错处理，打印出错位置和错误编码
 *  遇到错误就退出语法分析
 */	
void error(int n)
{
    char space[81];
    memset(space,32,81);

    space[currentPosition-1]=0; /* 出错时当前符号已经读完，所以 currentPosition-1 */
    
    printf("%s^%d\n", space, n);
    fprintf(foutput,"%s^%d\n", space, n);
    
    exit(1);
}

/*
 * 过滤空格，读取一个字符
 * 每次读一行，存入line缓冲区，line被getsym取空后再读一行
 * 被函数getsym调用
 */
void getch()
{
    /* 判断缓冲区中是否有字符，若无字符，则读入下一行字符到缓冲区中 */
    // lastPosition 指向一行末尾的位置
    // 如果 currentPosition == lastPosition 则表示这一行读完了
    if (currentPosition == lastPosition) {
        if (feof(fin)) {
            printf("Program incomplete!\n");
            exit(1);
        }
        lastPosition = 0;
        currentPosition = 0;
    
        ch = ' ';
        // 读入一整行
        while (ch != 10) {
            if (EOF == fscanf(fin,"%c", &ch)) {               
                line[lastPosition] = 0;
                break;
            }
            
            fprintf(foutput, "%c", ch);
            line[lastPosition] = ch;
            lastPosition++;
        }
    }
    ch = line[currentPosition];
    currentPosition++;
}

/* 
 * 词法分析，获取一个符号
 */
void getsym()
{
    int i,j,k;

    while (ch == ' ' || ch == 10 || ch == 9) {
        /* 过滤空格、换行和制表符 */
        getch();
    }
    if ((ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z')) /* 当前的单词是标识符或是保留字 */
    {			
        // 读完当前的单词
        k = 0;
        do {
            if(k < al) {
                a[k] = ch;
                k++;
            }
            getch();
        } while ((ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z') || (ch >= '0' && ch <= '9'));
        // 字符串末尾置 0
        a[k] = 0;
        strcpy(identifier, a);
        i = 0;
        j = norw - 1;
        do {    /* 搜索当前单词是否为保留字，使用二分法查找 */
            k = (i + j) / 2;
            if (strcmp(identifier,word[k]) <= 0) {
                j = k - 1;
            }
            if (strcmp(identifier,word[k]) >= 0) {
                i = k + 1;
            }
        } while (i <= j);
        if (i - 1 > j) /* 当前的单词是保留字 */
        {
            sym = wsym[k];
        }
        else /* 当前的单词是标识符 */
        {
            sym = ident; 
        }
    }
    else
    {
        if (ch >= '0' && ch <= '9') /* 当前的单词是数字 */
        {			
            k = 0;
            num = 0;
            sym = number;
            do {
                num = 10 * num + ch - '0';
                k++;
                getch();
            } while (ch >= '0' && ch <= '9'); /* 获取数字的值 */
            k--;
            if (k > nmax) /* 数字位数太多 */
            {
                error(30);
            }
        }
        else
        {
            if (ch == '=')		/* 检测赋值符号 */
            {
                getch();
                if (ch == '=')
                {
                    sym = becomes;
                    getch();
                }
                else
                {
                    sym = eql;
                }
            }
            else
            {
                if (ch == '<')		/* 检测小于或小于等于符号 */
                {
                    getch();
                    if (ch == '=')
                    {
                        sym = leq;
                        getch();
                    }
                    else
                    {
                        sym = lss;
                    }
                }
                else
                {
                    if (ch == '>')		/* 检测大于或大于等于符号 */
                    {
                        getch();
                        if (ch == '=')
                        {
                            sym = geq;
                            getch();
                        }
                        else
                        {
                            sym = gtr;
                        }
                    }
                    else {
                        if (ch == '!')	/* 检测不等于符号 */
                        {
                            getch();
                            if (ch == '=') {
                                sym = neq;
                                getch();
                            } else {
                                sym = nul;
                            }
                        }
                        else {
                            if (ch == '/')	/* 检测注释 */
                            {
                                getch();
                                if (ch == '*') {
                                    sym = comment;
                                    commentArea = true;
                                    while (true) {
                                        getch();
                                        /* 去掉注释中的内容 */
                                        while (ch == '*') {
                                            getch();
                                            if (ch == '/') {
                                                commentArea = false;
                                                break;
                                            }
                                        }
                                        if (!commentArea) break;
                                    }
                                    getch();
                                }
                                else {
                                    sym = divide;
                                }
                            }
                            else {
                                /* 当符号不满足上述条件时，全部按照单字符符号处理 */
                                sym = ssym[ch];
                                /* 计算嵌套层数 */
                                statementLevel += (sym == lbrace);
                                statementLevel -= (sym == rbrace);
                                if (statementLevel != 0) {
                                    getch();
                                }
                                // debug 用
                                if (statementLevel == 0) {
                                    finished = true;
                                }
                            }	
                        }
                    }
                }
            }
        }
    }
}