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
    ident,      number,     plus,       minus,      times,
    nul,        divide,     eql,        neq,        lss,
    leq,        gtr,        geq,        lparen,     rparen,
    comma,      semicolon,  lbracket,   rbracket,   lbrace,
    rbrace,     becomes,
    ifsym,      elsesym,    whilesym,   writesym,   readsym,
    mainsym,    intsym,     charsym,
}
#define symnum 30

/* 符号表中的类型 */
enum object {
    constant,
    variable, 
};

char ch;            /* 存放当前读取的字符，getch 使用 */
enum symbol sym;    /* 当前的符号 */
char id[al+1];      /* 当前ident，多出的一个字节用于存放0 */
int num;            /* 当前number */
int cc, ll;         /* getch使用的计数器，cc表示当前字符(ch)的位置 */
char line[81];      /* 读取行缓冲区 */
char a[al+1];       /* 临时符号，多出的一个字节用于存放0 */
char word[norw][al];        /* 保留字 */
enum symbol wsym[norw];     /* 保留字对应的符号值 */
enum symbol ssym[256];      /* 单字符的符号值 */

/* 符号表结构 */
struct tablestruct
{
	char name[al];	    /* 名字 */
	enum object kind;	/* 类型：const，var或procedure */
};

struct tablestruct table[txmax]; /* 符号表 */

FILE* fin;      /* 输入源文件 */
FILE* foutput;  /* 输出文件及出错示意（如有错） */
char fname[al];

/* 主程序开始 */
int main() {
    printf("Input x0 file: ");
	scanf("%s", fname);		/* 输入文件名 */

	if ((fin = fopen(fname, "r")) == NULL) {
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
	cc = ll = 0;
	ch = ' ';

	getsym();

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
    ssym['{'] = lparen;
    ssym['}'] = rparen;
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
 * 过滤空格，读取一个字符
 * 每次读一行，存入line缓冲区，line被getsym取空后再读一行
 * 被函数getsym调用
 */
void getch()
{
	/* 判断缓冲区中是否有字符，若无字符，则读入下一行字符到缓冲区中 */
	// ll 指向一行末尾的位置
	// 如果 cc == ll 则表示这一行读完了
	if (cc == ll)
	{
		if (feof(fin))
		{
			printf("Program incomplete!\n");
			exit(1);
		}
		ll = 0;
		cc = 0;
	
		ch = ' ';
		// 读入一整行
		while (ch != 10)
		{
            if (EOF == fscanf(fin,"%c", &ch))   
            {               
                line[ll] = 0;
                break;
            }                                   
            
			printf("%c", ch);
			fprintf(foutput, "%c", ch);
			line[ll] = ch;
			ll++;
		}
	}
	ch = line[cc];
	cc++;
}

/* 
 * 词法分析，获取一个符号
 */
void getsym()
{
	int i,j,k;

	while (ch == ' ' || ch == 10 || ch == 9)	/* 过滤空格、换行和制表符 */
	{
		getch();
	}
	if ((ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z')) /* 当前的单词是标识符或是保留字 */
	{			
		// 读完当前的单词
		k = 0;
		do {
			if(k < al)
			{
				a[k] = ch;
				k++;
			}
			getch();
		}while ((ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z') || (ch >= '0' && ch <= '9'));
		// 字符串末尾置 0
		a[k] = 0;
		strcpy(id, a);
		i = 0;
		j = norw - 1;
		do {    /* 搜索当前单词是否为保留字，使用二分法查找 */
			k = (i + j) / 2;
			if (strcmp(id,word[k]) <= 0)
			{
			    j = k - 1;
			}
			if (strcmp(id,word[k]) >= 0)
			{
			    i = k + 1;
			}
		} while (i <= j);
		if (i-1 > j) /* 当前的单词是保留字 */
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
			if (ch == ':')		/* 检测赋值符号 */
			{
				getch();
				if (ch == '=')
				{
					sym = becomes;
					getch();
				}
				else
				{
					sym = nul;	/* 不能识别的符号 */
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
					else
					{
						sym = ssym[ch];		/* 当符号不满足上述条件时，全部按照单字符符号处理 */                   
                        if (sym != period)  
                        {
                            getch();        
                        }
                   
					}
				}
			}
		}
	}
}