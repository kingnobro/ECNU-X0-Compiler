# ECNU 编译原理

## Environment

Ubuntu 18.04

安装 Lex 和 Yacc

```shell
sudo apt install flex
sudo apt install bison
```



## How To Run

```
make prog
./compiler -t -c src
```

- `src`: your source code file
- `-t`: show symbol table
- `-c`: show pcode



## Tutorial

- [A Guide To Lex & Yacc](https://arcb.csc.ncsu.edu/~mueller/codeopt/codeopt00/y_man.pdf)
- [Lex 与 Yacc 详解](https://zhuanlan.zhihu.com/p/143867739)



## Lex

只进行词法分析的样例在 `/Lex` 文件夹下，它可以将分析得到的 `token` 打印在屏幕上

```shell
flex pl0lex.l
cc lex.yy.c -o example
```

