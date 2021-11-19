---
layout: post
title: go 程序结构
date: 2021-11-19
Author: DDD
categories:
tags: [golang, lang]
comments: false
toc: true
pinned: true
---
## 语言的程序结构
所谓语言的程序结构，可以理解为一个程序源码由哪些基本组件和元素构成，如何组织和关联起来构成程序

通过比较老的 C 语言感受下

```
              C 程序
                |
    +-----------+-------------+
源码文件1   源码文件2 .... 源码文件n 
    |
    +------------+----------+--------+--------+
预处理命令 全局变量声明   函数1  函数2 ... 函数3
                            |
                     +----------+
                 函数首部   函数体
                                |
                        +-------------+
                   局部变量声明     执行语句
```

Demo.c

```c
#include <stdio.h>
#define DEBUG  // 以 # 开头的预处理命令

// 全局变量
int total = 0;

// 函数
void add(int num)  // 函数首部
{ // 函数体开始
    int a = 0;    // 局部变量声明
    total += num; // 执行语句
} // 函数体结束

// 函数
int main() {

    printf("hello world!\n"); // 执行语句

    for(int i=0; i<10; i++) {
        add(i);
    }
    printf("total=%d\n", total);

    return 1;
}
```
## go 程序结构
```
                          go 程序
                              |
    +-------------------------+-----------------+
    |                         |                 |
package 1                 package 2     ...   package n
                              |
                  +-----------+-------------+
         .go 源码文件1   .go 源码文件2 .... 源码文件n 
```

## go 源码结构

一个 go 源码文件的结构如下，可以看到声明所处的位置,   go 文法在 src/cmd/gc/go.y ，go 文法规则参见【Bison】

```go
//参见：go1.4-bootstrap/src/cmd/gc/go.y

file:					// .go 后缀文件
	loadsys			// 编译器可见, 程序员不可见
	package			// 表明 .go 文件所属的包
	imports			// import 声明
	xdcl_list		// 包级别的声明
	{
		xtop = concat(xtop, $4);
	}
```

从一个简单的 hello world 源码文件开始，观察一下内容，如下

```go
// hello.go

package main			// 所属包声明

import "fmt"			// 导入包声明
import "runtime"

func main() {			// 声明
  fmt.Printf("Hello, world!\n")
  fmt.Printf("Hello %s \n", runtime.Version())
}
```

可以看到 go 源码文件的主要构成，其中 package 部分可理解为声明源码文件归属于的 go 包， imports 部分是源码文件中引用的外部 go 包，比如 import "fmt"， xdlc_list 就是外部声明，也就描述源码的非终结符。



关于 loadsys 部分，在 src/cmd/gc/go.y 中有说明, 这个是 go 的运行时需要加载的 runtime 相关实现函数，这部分暂时先不细看

```go
/*
 * this loads the definitions for the low-level runtime functions,
 * so that the compiler can generate calls to them,
 * but does not make the name "runtime" visible as a package.
 */
```



可以通过如下命令，查看 loadsys 导入的运行时包

```bash
 go run --gcflags="-S -A" .\test1.go
# command-line-arguments
.\test1.go:6: export/package mismatch: runtime._func
.\test1.go:6: export/package mismatch: runtime.ncpu
.\test1.go:6: export/package mismatch: runtime.theVersion
```

### go 包和文件

#### package 包声明

可以观察下 go 源码中，如果没有 package 声明，会出现怎样情况， 如下

```go
$     cat test.go
// test.go
import "fmt"
import "runtime"
func main() {
  fmt.Printf("Hello, world!\n")
  fmt.Printf("Hello %s \n", runtime.Version())
}
$     go run test.go
test.go:2:1: expected 'package', found 'import'
```

可以看到报错信息

从  src/cmd/gc/go.y  中的文法可知， 这个 package 声明是必须要有的，而且必须是第一个声明的内容。 语法就是：

> 声明说明符   声明符    ;
>
> package 是声明说明符， sym 是声明符， 然后分号结束

```go
package:
	%prec NotPackage
	{
		prevlineno = lineno;
		yyerror("package statement must be first");
		errorexit();
	}
|	LPACKAGE sym ';'
	{
		mkpackage($2->name);
	}
```

所以，每一个 go 源码文件都需要在开头进行包声明。

从 go 的文法可以看到，当 go 编译器解析一个 go 文件时，遇到 package 包声明符，会执行 src/cmd/gc/lex.c 中的 void mkpackage(char* pkgname)  函数创建一个包



在 一个 go 的应用程序中， 只能有一个 package main 包，在其中声明应用程序的入口， func main() {}



可以在多个 go 文件中声明相同的包，比如 在 test1.go 和 test2.go 中都声明了 package test

```go
test1.go

package test

func test1() {
...
}
```

```go
test2.go

package test

func test2() {
...
}
```



go 是通过路径来查找和关联包的，通常包名是导入路径的最后一段， 所以一个包比如 package test  的相关代码文件通常放在包同名的 test 文件夹下



#### imports 导入包

从 go.y 可看出， go 的源码中有  imports 非终结符 ，此部分是声明导入当前包需要依赖引用的外部包

import 导入包一般有两种形式的写法， 如下

```go
package main
import (
	"fmt"
	"runtime"
)

// ------------

package main
import "fmt"
import "runtime"
```

在 go.y  中我们可以看到  imports 的声明是可以有多个。 上面的两个例子对应了 import 的规则下的第1和第2种形式， 文法如下

```go
imports:
|	imports import ';'

import:
	LIMPORT import_stmt
|	LIMPORT '(' import_stmt_list osemi ')'
|	LIMPORT '(' ')'
```

其中，第三种形式的代码，也能跑，编译器没报错

```
$     cat test2.go
package main

import ()

func main() {
}
$     go run test2.go
```



##### import_stmt

详细看下第一种包导入的写法， import_stmt

```go

import_stmt:
	import_here import_package import_there {...}
	|	import_here import_there {...}	
```

先看下 import_stmt 中 相对简单的第二种  import_here import_there {...}  go 代码形式，如下能编译，能跑，  效果就是"别名操作"

```go
$     cat test2.go
package main

import (
	f "fmt"
)

func main() {
	f.Printf("Hello, world!\n")
}

// ------------------

$     go run test2.go
Hello, world!
```

继续展开， import_here 非终结符下面三种情况都可以，上面这个列子对应的规则是 |	sym LLITERAL {...} ， f 是声明符 

```go
import_here:
	LLITERAL{...}						// 按包的原始命名导入
|	sym LLITERAL {...}			// 导入包，然后给一个别名
|	'.' LLITERAL {...}			// 包导入到本地命名空间
```

看下上面 import_here 非终结符列出第三种情况 |	'.' LLITERAL {...}，也能编译过，能跑

```go
$     cat test2.go
package main

import (
	. "fmt"
)

func main() {
	Printf("Hello, world!\n")
}

// ---------------

$     go run test2.go
Hello, world!
```



#####  import_stmt_list

```go
package main
import (
	"fmt"
	"runtime"
)
```

```go
import_stmt_list:
	import_stmt
|	import_stmt_list ';' import_stmt
```

可以看到， "fmt" 就是一个 import_stmt， "fmt" 和 "runtime" 构成了 import_stmt_list 

###### import_package

import_stmt  非终结符继续展开， 如下

```
import_package:
	LPACKAGE LNAME import_safety ';'
```



##### 包导入的处理函数

当 go 编译器解析完成 import 声明的包路径后，会调用  src/cmd/gc/lex.c  中的 void importfile(Val *f, int line)  函数处理包的导入



从 static int findpkg(Strlit *name) 中可以看到 go 编译器是如何查找到 package 包的

先从本地路径加查找， 如 ./ 和../ 等路径下

然后从 I 参数导入的路径中查找

最后从 GOROOT 环境变量中查找

## go 源码 AST
```
                  Package
                     |
        +------------+----------------+
    ast.File 1     ast.File 2    ... ast.File n
                     |
                    ast.Decl
      +--------------+--------------------+
  ast.GenDecl                     ast.FuncDecl
```


## 参考

- 《Go语言程序设计》
- 《计算机程序的构造和解释》
- 《计算机科学概论》
- go1.4-bootstrap
- Bison
