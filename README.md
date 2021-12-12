# ECNU-X0-Compiler

只实现了必做的和简单的扩展功能（:fish:）

## Tree

```
├── Makefile			# build
├── README.md
├── compiler.l		# lex
├── compiler.y		# yacc
└── test					# 测试用的 X0源文件
```



## Build

```
make
./compiler
```



## GUI

- GTK+ 2.0
- Reference: [link](https://github.com/mizunashi-sh/NaiveCompiler)



```c++
// macOS 安装 gtk+
xcode-select --install
brew install gtk+
```

```c++
// 安装成功后, 需要包含头文件
#include <gtk/gtk.h>

// 同时编译时需要链接, 详见 Makefile
```



![image-20211212215419625](https://tva1.sinaimg.cn/large/008i3skNgy1gxbe5dvosnj316o0u0ju6.jpg)