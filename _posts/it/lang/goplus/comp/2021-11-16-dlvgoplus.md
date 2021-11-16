---
layout: post
title: Hello World
date: 2021-11-16
Author: DDD
categories:
tags: [sample, document]
comments: false
toc: true
pinned: true
---
## goplus 初探
gop 命令由 gop-1.0.16/cmd/gop/main.go 编译生成
gop run hello.gop 类似 go run 命令运行一个源码文件
调试一下看看具体的一些工作过程

### dlv debug
在翻代码的的过程中，顺带在源码里增加了有一些打印代码，和官方的源码在代码对应的行数上略有些偏差

给 gop 程序的入口设个断点
```bash
$     dlv debug ../../gop-1.0.16/cmd/gop/main.go
Type 'help' for list of commands.
(dlv) b main.main
Breakpoint 1 set at 0x1484a52 for main.main() goplus/gop-1.0.16/cmd/gop/main.go:58
```

给 gop run 命令的执行入口设个断点
```bash
(dlv) b run.runCmd
Breakpoint 2 set at 0x1480292 for github.com/goplus/gop/cmd/internal/run.runCmd() goplus/src/github.com/goplus/gop/cmd/internal/run/run.go:98
```

在官方的发布目录下有个简单的例子
```go
// gop-1.0.16/tutorial/01-Hello-world/hello.gop
println("Hello, world!")
```

跑例子代码前，把对一个的 go 文件删除一下
```bash
rm gop_autogen_hello.gop.go
```


跑下 hello.gop 源码文件
```bash
(dlv) r run hello.gop
Process restarted with PID 5572
(dlv) c
> main.main() goplus/gop-1.0.16/cmd/gop/main.go:58 (hits goroutine(1):1 total:1) (PC: 0x1484a52)
    53:			test.Cmd,
    54:			version.Cmd,
    55:		}
    56:	}
    57:
=>  58:	func main() {
    59:		flag.Parse()
    60:		args := flag.Args()
    61:		if len(args) < 1 {
    62:			base.Usage()
    63:		}
(dlv)
```

再 c 到 run 的命令入口，看下调用栈
```bash
(dlv) bt
0 0x000000000148048f in github.com/goplus/gop/cmd/internal/run.runCmd
at goplus/src/github.com/goplus/gop/cmd/internal/run/run.go:108
1 0x0000000001485234 in main.main
at goplus/gop-1.0.16/cmd/gop/main.go:95
2 0x0000000001038433 in runtime.main
at /usr/local/Cellar/go/1.17.2/libexec/src/runtime/proc.go:255
3 0x0000000001066601 in runtime.goexit
at /usr/local/Cellar/go/1.17.2/libexec/src/runtime/asm_amd64.s:1581
```

n 一下代码的执行，找下输入的 hello.gop 源码文件信息, 后面主要是关注这个源码文件的处理过程
```bash
147: } else {
148: srcDir, file = filepath.Split(src)
=> 149: isGo := filepath.Ext(file) == ".go"
150: if isGo {


(dlv) p file
"hello.gop"
```

从编译原理的知识看，是会有个入口对 hello.gop 源文件做处理的
逐行 n 一下可以发现 parser 的入口，大致类似 go parser 的机制

```bash
=> 172:					pkgs, err = parser.Parse(fset, src, nil, 0) // TODO: only to check dependencies
   173:				}
   174:			} else if *flagNorun {
   175:				return
```

### 词法分析

设置下 parser 的入口断点, 看下调用栈

```bash
(dlv) b parser.Parse

(dlv) bt
0 0x000000000141aa2f in github.com/goplus/gop/parser.Parse
at goplus/src/github.com/goplus/gop/parser/parser_gop.go:77
1 0x000000000148109e in github.com/goplus/gop/cmd/internal/run.runCmd
at goplus/src/github.com/goplus/gop/cmd/internal/run/run.go:171
2 0x0000000001485234 in main.main
at goplus/gop-1.0.16/cmd/gop/main.go:95
3 0x0000000001038433 in runtime.main
at /usr/local/Cellar/go/1.17.2/libexec/src/runtime/proc.go:255
4 0x0000000001066601 in runtime.goexit
at /usr/local/Cellar/go/1.17.2/libexec/src/runtime/asm_amd64.s:1581
```

一些列的 parser 调用之后，看到了把源码文件内容读入内存中，形成字节流
```bash
(dlv) bt
0 0x000000000141bdb2 in github.com/goplus/gop/parser.parseFSFileEx
at goplus/src/github.com/goplus/gop/parser/parser_gop.go:203
1 0x000000000141bcaa in github.com/goplus/gop/parser.ParseFSFile
at goplus/src/github.com/goplus/gop/parser/parser_gop.go:200
2 0x000000000141ba97 in github.com/goplus/gop/parser.ParseFile
at goplus/src/github.com/goplus/gop/parser/parser_gop.go:190
3 0x000000000141ab8f in github.com/goplus/gop/parser.Parse
at goplus/src/github.com/goplus/gop/parser/parser_gop.go:80
4 0x000000000148109e in github.com/goplus/gop/cmd/internal/run.runCmd
at goplus/src/github.com/goplus/gop/cmd/internal/run/run.go:171
5 0x0000000001485234 in main.main
at goplus/gop-1.0.16/cmd/gop/main.go:95
6 0x0000000001038433 in runtime.main
at /usr/local/Cellar/go/1.17.2/libexec/src/runtime/proc.go:255
7 0x0000000001066601 in runtime.goexit
at /usr/local/Cellar/go/1.17.2/libexec/src/runtime/asm_amd64.s:1581


205: if src == nil {
206: code, err = fs.ReadFile(filename) // 读文件的源码内容
207: } else {
208: code, err = readSource(src)
209: }
=> 210: if err != nil {

(dlv) p code
[]uint8 len: 25, cap: 512, [112,114,105,110,116,108,110,40,34,72,101,108,108,111,44,32,119,111,114,108,100,33,34,41,10]
```

读取源码内容后，继续调用 parser 的相关解析函数
```bash
> github.com/goplus/gop/parser.parseFile() goplus/src/github.com/goplus/gop/parser/interface.go:74 (PC: 0x13fc815)
    69:		if fset == nil {
    70:			panic("parser.ParseFile: no token.FileSet provided (fset == nil)")
    71:		}
    72:
    73:		// get source
=>  74:		text, err := readSource(src)
    75:		if err != nil {
    76:			return nil, err
    77:		}
```

看下 parser.readSource 的调用栈

```bash
/goplus/gop/parser/parser_gop.go:285 (PC: 0x141d0ad)
(dlv) bt
 0  0x000000000141d071 in github.com/goplus/gop/parser.readSource
    at goplus/src/github.com/goplus/gop/parser/parser_gop.go:282
 1  0x00000000013fc848 in github.com/goplus/gop/parser.parseFile
    at goplus/src/github.com/goplus/gop/parser/interface.go:74
 2  0x000000000141c48c in github.com/goplus/gop/parser.parseFileEx
    at goplus/src/github.com/goplus/gop/parser/parser_gop.go:228
 3  0x000000000141c107 in github.com/goplus/gop/parser.parseFSFileEx
    at goplus/src/github.com/goplus/gop/parser/parser_gop.go:216
 4  0x000000000141bcaa in github.com/goplus/gop/parser.ParseFSFile
    at goplus/src/github.com/goplus/gop/parser/parser_gop.go:200
 5  0x000000000141ba97 in github.com/goplus/gop/parser.ParseFile
    at goplus/src/github.com/goplus/gop/parser/parser_gop.go:190
 6  0x000000000141ab8f in github.com/goplus/gop/parser.Parse
    at goplus/src/github.com/goplus/gop/parser/parser_gop.go:80
 7  0x000000000148109e in github.com/goplus/gop/cmd/internal/run.runCmd
    at goplus/src/github.com/goplus/gop/cmd/internal/run/run.go:171
 8  0x0000000001485234 in main.main
    at goplus/gop-1.0.16/cmd/gop/main.go:95
 9  0x0000000001038433 in runtime.main
    at /usr/local/Cellar/go/1.17.2/libexec/src/runtime/proc.go:255
10  0x0000000001066601 in runtime.goexit
    at /usr/local/Cellar/go/1.17.2/libexec/src/runtime/asm_amd64.s:1581
```

源码内容继续传递往下调用
这里构建一个解析器对象 p，专门解析这个源码
```bash
goplus/gop/parser/interface.go:107 (PC: 0x13fcb6f)
   102:			p.errors.Sort()
   103:			err = p.errors.Err()
   104:		}()
   105:
   106:		// parse source
=> 107:		p.init(fset, filename, text, mode)
   108:		f = p.parseFile()
   109:
   110:		return
   111:	}
   112:
(dlv) p text
[]uint8 len: 25, cap: 512, [112,114,105,110,116,108,110,40,34,72,101,108,108,111,44,32,119,111,114,108,100,33,34,41,10]
(dlv) p mode
PackageClauseOnly (1)
(dlv) bt
```

看下 p 对象的内容, 源码文件的字节流内容已经设置进入了

```bash
(dlv) p p
github.com/goplus/gop/parser.parser {
	file: *go/token.File {
		set: *(*"go/token.FileSet")(0xc0000baa40),
		name: "goplus...+22 more",
		base: 1,
		size: 25,
		mutex: (*sync.Mutex)(0xc0000b8508),
		lines: []int len: 1, cap: 1, [0],
		infos: []go/token.lineInfo len: 0, cap: 0, nil,},
	errors: go/scanner.ErrorList len: 0, cap: 0, nil,
	scanner: github.com/goplus/gop/scanner.Scanner {
		file: *(*"go/token.File")(0xc0000b84e0),
		dir: "goplus...+13 more",
		src: []uint8 len: 25, cap: 512, [112,114,105,110,116,108,110,40,34,72,101,108,108,111,44,32,119,111,114,108,100,33,34,41,10],
		err: github.com/goplus/gop/parser.(*parser).init.func1,
		mode: 0,
		ch: 40,
		offset: 7,
		rdOffset: 8,
		lineOffset: 0,
		insertSemi: true,
		ErrorCount: 0,},
	mode: PackageClauseOnly (1),
	trace: false,
	indent: 0,
	comments: []*github.com/goplus/gop/ast.CommentGroup len: 0, cap: 0, nil,
	leadComment: *github.com/goplus/gop/ast.CommentGroup nil,
	lineComment: *github.com/goplus/gop/ast.CommentGroup nil,
	pos: github.com/goplus/gox.InstrFlagEllipsis (1),
	tok: IDENT (4),
	lit: "println",
	old: struct { github.com/goplus/gop/parser.pos go/token.Pos; github.com/goplus/gop/parser.tok github.com/goplus/gop/token.Token; github.com/goplus/gop/parser.lit string } {pos: NoPos (0), tok: ILLEGAL (0), lit: ""},
	syncPos: NoPos (0),
	syncCnt: 0,
	exprLev: 0,
	inRHS: false,
	pkgScope: *github.com/goplus/gop/ast.Scope nil,
	topScope: *github.com/goplus/gop/ast.Scope nil,
	unresolved: []*github.com/goplus/gop/ast.Ident len: 0, cap: 0, nil,
	imports: []*github.com/goplus/gop/ast.ImportSpec len: 0, cap: 0, nil,
	labelScope: *github.com/goplus/gop/ast.Scope nil,
	targetStack: [][]*github.com/goplus/gop/ast.Ident len: 0, cap: 0, nil,}
(dlv)
```

接着调用 p 解析器的 parseFile 函数，看下调用栈

```bash
>3151:	func (p *parser) parseFile() *ast.File {
  3152:
  3153:		
  3154:
  3155:		if p.trace {
  3156:			defer un(trace(p, "File"))
(dlv) bt
 0  0x0000000001419a92 in github.com/goplus/gop/parser.(*parser).parseFile
    at goplus/src/github.com/goplus/gop/parser/parser.go:3151
 1  0x00000000013fcbc5 in github.com/goplus/gop/parser.parseFile
    at goplus/src/github.com/goplus/gop/parser/interface.go:108
 2  0x000000000141c48c in github.com/goplus/gop/parser.parseFileEx
    at goplus/src/github.com/goplus/gop/parser/parser_gop.go:228
 3  0x000000000141c107 in github.com/goplus/gop/parser.parseFSFileEx
    at goplus/src/github.com/goplus/gop/parser/parser_gop.go:216
 4  0x000000000141bcaa in github.com/goplus/gop/parser.ParseFSFile
    at goplus/src/github.com/goplus/gop/parser/parser_gop.go:200
 5  0x000000000141ba97 in github.com/goplus/gop/parser.ParseFile
    at goplus/src/github.com/goplus/gop/parser/parser_gop.go:190
 6  0x000000000141ab8f in github.com/goplus/gop/parser.Parse
    at goplus/src/github.com/goplus/gop/parser/parser_gop.go:80
 7  0x000000000148109e in github.com/goplus/gop/cmd/internal/run.runCmd
    at goplus/src/github.com/goplus/gop/cmd/internal/run/run.go:171
 8  0x0000000001485234 in main.main
    at goplus/gop-1.0.16/cmd/gop/main.go:95
 9  0x0000000001038433 in runtime.main
    at /usr/local/Cellar/go/1.17.2/libexec/src/runtime/proc.go:255
10  0x0000000001066601 in runtime.goexit
    at /usr/local/Cellar/go/1.17.2/libexec/src/runtime/asm_amd64.s:1581
```

然后又一系列的解析函数调用，到了这里
看下面这个函数返回的 err 不为空，大概就是还没有能构成一个完整的 go AST, 比如缺了 package 声明
对源码中追加补齐 package main 的声明

```bash
228:		f, err = parseFile(fsetTmp, filename, code, PackageClauseOnly) //  在 package 子句之后停止解析
   229:		if err != nil {
=> 230:			fmt.Fprintf(&b, "package main;%s", code) // 添加点东西， eg:  package main;a := [1, 2, 3.4]
   231:			code = b.Bytes()
   232:			noPkgDecl = true
(dlv) bt
0  0x000000000141c4e5 in github.com/goplus/gop/parser.parseFileEx
   at goplus/src/github.com/goplus/gop/parser/parser_gop.go:230
1  0x000000000141c107 in github.com/goplus/gop/parser.parseFSFileEx
   at goplus/src/github.com/goplus/gop/parser/parser_gop.go:216
2  0x000000000141bcaa in github.com/goplus/gop/parser.ParseFSFile
   at goplus/src/github.com/goplus/gop/parser/parser_gop.go:200
3  0x000000000141ba97 in github.com/goplus/gop/parser.ParseFile
   at goplus/src/github.com/goplus/gop/parser/parser_gop.go:190
4  0x000000000141ab8f in github.com/goplus/gop/parser.Parse
   at goplus/src/github.com/goplus/gop/parser/parser_gop.go:80
5  0x000000000148109e in github.com/goplus/gop/cmd/internal/run.runCmd
   at goplus/src/github.com/goplus/gop/cmd/internal/run/run.go:171
6  0x0000000001485234 in main.main
   at goplus/gop-1.0.16/cmd/gop/main.go:95
7  0x0000000001038433 in runtime.main
   at /usr/local/Cellar/go/1.17.2/libexec/src/runtime/proc.go:255
8  0x0000000001066601 in runtime.goexit
   at /usr/local/Cellar/go/1.17.2/libexec/src/runtime/asm_amd64.s:1581
```

补齐了代码，继续调用解析

```bash
=> 245:		_, err = parseFile(fsetTmp, filename, code, mode)
   246:		if err != nil {
   247:			if errlist, ok := err.(scanner.ErrorList); ok {
   248:				if e := errlist[0]; strings.HasPrefix(e.Msg, "expected declaration") {
   249:					var entrypoint string
```

继续新的一轮源码内容解析

```bash
goplus/gop/parser/interface.go:67 (PC: 0x13fc72e)
    62:	// representing the fragments of erroneous source code). Multiple errors
    63:	// are returned via a scanner.ErrorList which is sorted by source position.
    64:	//
    65:	func parseFile(fset *token.FileSet, filename string, src interface{}, mode Mode) (f *ast.File, err error) {
    66:
=>  67:		
    68:
    69:		if fset == nil {
    70:			panic("parser.ParseFile: no token.FileSet provided (fset == nil)")
    71:		}
    72:
(dlv) bt
0  0x00000000013fc72e in github.com/goplus/gop/parser.parseFile
   at goplus/src/github.com/goplus/gop/parser/interface.go:67
1  0x000000000141c865 in github.com/goplus/gop/parser.parseFileEx
   at goplus/src/github.com/goplus/gop/parser/parser_gop.go:239
2  0x000000000141c107 in github.com/goplus/gop/parser.parseFSFileEx
   at goplus/src/github.com/goplus/gop/parser/parser_gop.go:216
3  0x000000000141bcaa in github.com/goplus/gop/parser.ParseFSFile
   at goplus/src/github.com/goplus/gop/parser/parser_gop.go:200
4  0x000000000141ba97 in github.com/goplus/gop/parser.ParseFile
   at goplus/src/github.com/goplus/gop/parser/parser_gop.go:190
5  0x000000000141ab8f in github.com/goplus/gop/parser.Parse
   at goplus/src/github.com/goplus/gop/parser/parser_gop.go:80
6  0x000000000148109e in github.com/goplus/gop/cmd/internal/run.runCmd
   at goplus/src/github.com/goplus/gop/cmd/internal/run/run.go:171
7  0x0000000001485234 in main.main
   at goplus/gop-1.0.16/cmd/gop/main.go:95
8  0x0000000001038433 in runtime.main
   at /usr/local/Cellar/go/1.17.2/libexec/src/runtime/proc.go:255
9  0x0000000001066601 in runtime.goexit
   at /usr/local/Cellar/go/1.17.2/libexec/src/runtime/asm_amd64.s:1581
```

补 main 模块的 main.main 函数入口
```bash
goplus/gop/parser/parser_gop.go:259 (PC: 0x141ca38)
   254:						entrypoint = "func MainEntry()"
   255:					default:
   256:						if isMod {
   257:							entrypoint = "func init()"
   258:						} else {
=> 259:							entrypoint = "func main()"
   260:						}
   261:					}
```

```bash
goplus/gop/parser/parser_gop.go:273 (PC: 0x141ce25)
   268:				}
   269:			}
   270:		}
   271:		if err == nil {
   272:			// 到这里，说明把 go 的语法都补齐了
=> 273:			f, err = parseFile(fset, filename, code, mode)
   274:			if err == nil {
   275:				f.NoEntrypoint = noEntrypoint
   276:				f.NoPkgDecl = noPkgDecl
   277:				f.FileType = extGopFiles[filepath.Ext(filename)]
   278:			}
```

开始解析一个完整的 go 源码内容

```bash
goplus/gop/parser/parser.go:3185 (PC: 0x1419e1c)
  3180:		}
  3181:
  3182:		p.openScope()
  3183:		p.pkgScope = p.topScope
  3184:		var decls []ast.Decl
=>3185:		if p.mode&PackageClauseOnly == 0 {
  3186:			// import decls
  3187:			for p.tok == token.IMPORT {
  3188:				//eg: import "fmt"
  3189:				decls = append(decls, p.parseGenDecl(token.IMPORT, p.parseImportSpec)) // eg: import、type、const
  3190:			}
(dlv) p p.pkgScope
*github.com/goplus/gop/ast.Scope {
	Outer: *github.com/goplus/gop/ast.Scope nil,
	Objects: map[string]*github.com/goplus/gop/ast.Object [],}
(dlv)
```

```
(dlv) b run.go:228
Breakpoint 4 set at 0x14818a2 for github.com/goplus/gop/cmd/internal/run.runCmd() goplus/src/github.com/goplus/gop/cmd/internal/run/run.go:228

package main; func main(){println("Hello, world!")}

     0  *ast.Package {
     1  .  Name: "main"
     2  .  Files: map[string]*ast.File (len = 1) {
     3  .  .  "goplus/src/testgop/hello.gop": *ast.File {
     4  .  .  .  Package: goplus/src/testgop/hello.gop:1:1
     5  .  .  .  Name: *ast.Ident {
     6  .  .  .  .  NamePos: goplus/src/testgop/hello.gop:1:9
     7  .  .  .  .  Name: "main"
     8  .  .  .  }
     9  .  .  .  Decls: []ast.Decl (len = 1) {
    10  .  .  .  .  0: *ast.FuncDecl {
    11  .  .  .  .  .  Name: *ast.Ident {
    12  .  .  .  .  .  .  NamePos: goplus/src/testgop/hello.gop:1:20
    13  .  .  .  .  .  .  Name: "main"
    14  .  .  .  .  .  .  Obj: *ast.Object {
    15  .  .  .  .  .  .  .  Kind: func
    16  .  .  .  .  .  .  .  Name: "main"
    17  .  .  .  .  .  .  .  Decl: *(obj @ 10)
    18  .  .  .  .  .  .  }
    19  .  .  .  .  .  }
    20  .  .  .  .  .  Type: *ast.FuncType {
    21  .  .  .  .  .  .  Func: goplus/src/testgop/hello.gop:1:15
    22  .  .  .  .  .  .  Params: *ast.FieldList {
    23  .  .  .  .  .  .  .  Opening: goplus/src/testgop/hello.gop:1:24
    24  .  .  .  .  .  .  .  Closing: goplus/src/testgop/hello.gop:1:25
    25  .  .  .  .  .  .  }
    26  .  .  .  .  .  }
    27  .  .  .  .  .  Body: *ast.BlockStmt {
    28  .  .  .  .  .  .  Lbrace: goplus/src/testgop/hello.gop:1:26
    29  .  .  .  .  .  .  List: []ast.Stmt (len = 1) {
    30  .  .  .  .  .  .  .  0: *ast.ExprStmt {
    31  .  .  .  .  .  .  .  .  X: *ast.CallExpr {
    32  .  .  .  .  .  .  .  .  .  Fun: *ast.Ident {
    33  .  .  .  .  .  .  .  .  .  .  NamePos: goplus/src/testgop/hello.gop:1:27
    34  .  .  .  .  .  .  .  .  .  .  Name: "println"
    35  .  .  .  .  .  .  .  .  .  }
    36  .  .  .  .  .  .  .  .  .  Lparen: goplus/src/testgop/hello.gop:1:34
    37  .  .  .  .  .  .  .  .  .  Args: []ast.Expr (len = 1) {
    38  .  .  .  .  .  .  .  .  .  .  0: *ast.BasicLit {
    39  .  .  .  .  .  .  .  .  .  .  .  ValuePos: goplus/src/testgop/hello.gop:1:35
    40  .  .  .  .  .  .  .  .  .  .  .  Kind: STRING
    41  .  .  .  .  .  .  .  .  .  .  .  Value: "\"Hello, world!\""
    42  .  .  .  .  .  .  .  .  .  .  }
    43  .  .  .  .  .  .  .  .  .  }
    44  .  .  .  .  .  .  .  .  .  Ellipsis: -
    45  .  .  .  .  .  .  .  .  .  Rparen: goplus/src/testgop/hello.gop:1:50
    46  .  .  .  .  .  .  .  .  .  NoParenEnd: -
    47  .  .  .  .  .  .  .  .  }
    48  .  .  .  .  .  .  .  }
    49  .  .  .  .  .  .  }
    50  .  .  .  .  .  .  Rbrace: goplus/src/testgop/hello.gop:3:1
    51  .  .  .  .  .  }
    52  .  .  .  .  .  Operator: false
    53  .  .  .  .  }
    54  .  .  .  }
    55  .  .  .  Scope: *ast.Scope {
    56  .  .  .  .  Objects: map[string]*ast.Object (len = 1) {
    57  .  .  .  .  .  "main": *(obj @ 14)
    58  .  .  .  .  }
    59  .  .  .  }
    60  .  .  .  Unresolved: []*ast.Ident (len = 1) {
    61  .  .  .  .  0: *(obj @ 32)
    62  .  .  .  }
    63  .  .  .  Code: "package main; func main(){println(\"Hello, world!\")\n\n}"
    64  .  .  .  NoEntrypoint: true
    65  .  .  .  NoPkgDecl: true
    66  .  .  .  FileType: 0
    67  .  .  }
    68  .  }
    69  }
```



### 语法分析

开始要做声明语法的分析

```bash
goplus/src/github.com/goplus/gop/parser/parser.go:3196 (PC: 0x141a592)
  3191:
  3192:			if p.mode&ImportsOnly == 0 {
  3193:				// rest of package body
  3194:				for p.tok != token.EOF {
  3195:					// 语法分析
=>3196:					decls = append(decls, p.parseDecl(declStart))
  3197:				}
  3198:			}
  3199:		}
```

看下声明语法分析的入口

```
goplus/gop/parser/parser.go:3120 (PC: 0x1419602)
  3115:		return decl
  3116:	}
  3117:
  3118:	// 声明语法分析
  3119:	func (p *parser) parseDecl(sync map[token.Token]bool) ast.Decl {
=>3120:		if p.trace {
  3121:			defer un(trace(p, "Declaration"))
  3122:		}
  3123:		var f parseSpecFunction
  3124:		pos := p.pos
  3125:		switch p.tok {
(dlv) bt
 0  0x0000000001419602 in github.com/goplus/gop/parser.(*parser).parseDecl
    at goplus/src/github.com/goplus/gop/parser/parser.go:3120
 1  0x000000000141a5a6 in github.com/goplus/gop/parser.(*parser).parseFile
    at goplus/src/github.com/goplus/gop/parser/parser.go:3196
 2  0x00000000013fcbc5 in github.com/goplus/gop/parser.parseFile
    at goplus/src/github.com/goplus/gop/parser/interface.go:108
 3  0x000000000141c865 in github.com/goplus/gop/parser.parseFileEx
    at goplus/src/github.com/goplus/gop/parser/parser_gop.go:239
 4  0x000000000141c107 in github.com/goplus/gop/parser.parseFSFileEx
    at goplus/src/github.com/goplus/gop/parser/parser_gop.go:216
 5  0x000000000141bcaa in github.com/goplus/gop/parser.ParseFSFile
    at goplus/src/github.com/goplus/gop/parser/parser_gop.go:200
 6  0x000000000141ba97 in github.com/goplus/gop/parser.ParseFile
    at goplus/src/github.com/goplus/gop/parser/parser_gop.go:190
 7  0x000000000141ab8f in github.com/goplus/gop/parser.Parse
    at goplus/src/github.com/goplus/gop/parser/parser_gop.go:80
 8  0x000000000148109e in github.com/goplus/gop/cmd/internal/run.runCmd
    at goplus/src/github.com/goplus/gop/cmd/internal/run/run.go:171
 9  0x0000000001485234 in main.main
    at goplus/gop-1.0.16/cmd/gop/main.go:95
10  0x0000000001038433 in runtime.main
    at /usr/local/Cellar/go/1.17.2/libexec/src/runtime/proc.go:255
11  0x0000000001066601 in runtime.goexit
    at /usr/local/Cellar/go/1.17.2/libexec/src/runtime/asm_amd64.s:1581
(dlv)
```

因为之前把源码补齐了内容，main package 下实际只有一个 func main() 函数声明，
函数中包裹了 hello.gop 中的那行代码
```go
println("Hello, world!")
```

所以语法解析进入到了 token.FUNC 函数声明中进行解析

```bash
goplus/src/github.com/goplus/gop/parser/parser.go:3133 (PC: 0x1419727)
  3128:
  3129:		case token.TYPE:	// type 声明
  3130:			f = p.parseTypeSpec
  3131:
  3132:		case token.FUNC:	// func 函数声明
=>3133:			decl := p.parseFuncDecl()
  3134:			if p.errors.Len() != 0 {
  3135:				p.errorExpected(pos, "declaration", 2)
  3136:				p.advance(sync)
  3137:			}
  3138:			return decl
```

看下对 func main 函数声明解析的处理调用栈

```bash
goplus/src/github.com/goplus/gop/parser/parser.go:3056 (PC: 0x1418ddf)
  3051:	func (p *parser) parseFuncDecl() *ast.FuncDecl {
  3052:		if p.trace {
  3053:			defer un(trace(p, "FunctionDecl"))
  3054:		}
  3055:
=>3056:		doc := p.leadComment
  3057:		pos := p.expect(token.FUNC)
  3058:		scope := ast.NewScope(p.topScope) // function scope
  3059:
  3060:		var recv *ast.FieldList
  3061:		if p.tok == token.LPAREN {
(dlv) bt
 0  0x0000000001418ddf in github.com/goplus/gop/parser.(*parser).parseFuncDecl
    at goplus/src/github.com/goplus/gop/parser/parser.go:3056
 1  0x0000000001419734 in github.com/goplus/gop/parser.(*parser).parseDecl
    at goplus/src/github.com/goplus/gop/parser/parser.go:3133
 2  0x000000000141a5a6 in github.com/goplus/gop/parser.(*parser).parseFile
    at goplus/src/github.com/goplus/gop/parser/parser.go:3196
 3  0x00000000013fcbc5 in github.com/goplus/gop/parser.parseFile
    at goplus/src/github.com/goplus/gop/parser/interface.go:108
 4  0x000000000141ce8e in github.com/goplus/gop/parser.parseFileEx
    at goplus/src/github.com/goplus/gop/parser/parser_gop.go:273
 5  0x000000000141c107 in github.com/goplus/gop/parser.parseFSFileEx
    at goplus/src/github.com/goplus/gop/parser/parser_gop.go:222
 6  0x000000000141bcaa in github.com/goplus/gop/parser.ParseFSFile
    at goplus/src/github.com/goplus/gop/parser/parser_gop.go:206
 7  0x000000000141ba97 in github.com/goplus/gop/parser.ParseFile
    at goplus/src/github.com/goplus/gop/parser/parser_gop.go:196
 8  0x000000000141ab8f in github.com/goplus/gop/parser.Parse
    at goplus/src/github.com/goplus/gop/parser/parser_gop.go:80
 9  0x000000000148109e in github.com/goplus/gop/cmd/internal/run.runCmd
    at goplus/src/github.com/goplus/gop/cmd/internal/run/run.go:172
10  0x0000000001485234 in main.main
    at goplus/gop-1.0.16/cmd/gop/main.go:95
11  0x0000000001038433 in runtime.main
    at /usr/local/Cellar/go/1.17.2/libexec/src/runtime/proc.go:255
12  0x0000000001066601 in runtime.goexit
    at /usr/local/Cellar/go/1.17.2/libexec/src/runtime/asm_amd64.s:1581
(dlv)
```

准备开始处理函数体内容

```bash
goplus/src/github.com/goplus/gop/parser/parser.go:3075 (PC: 0x1418ff6)
  3070:			}
  3071:		}
  3072:
  3073:		var body *ast.BlockStmt
  3074:		if p.tok == token.LBRACE {
=>3075:			body = p.parseBody(scope)
  3076:			p.expectSemi()
  3077:		} else if p.tok == token.SEMICOLON {
  3078:			p.next()
  3079:			if p.tok == token.LBRACE {
  3080:				// opening { of function declaration on next line
```

准备处理函数内的声明语句

```bash
/goplus/src/github.com/goplus/gop/parser/parser.go:1309 (PC: 0x1407cf6)
  1304:		}
  1305:
  1306:		lbrace := p.expect(token.LBRACE)
  1307:		p.topScope = scope // open function scope
  1308:		p.openLabelScope()
=>1309:		list := p.parseStmtList()
  1310:		p.closeLabelScope()
  1311:		p.closeScope()
  1312:		rbrace := p.expect2(token.RBRACE)
  1313:
  1314:		return &ast.BlockStmt{Lbrace: lbrace, List: list, Rbrace: rbrace}
```

看下语句列表处理的调用栈

```bash
goplus/src/github.com/goplus/gop/parser/parser.go:1294 (PC: 0x1407991)
  1289:	func (p *parser) parseStmtList() (list []ast.Stmt) {
  1290:		if p.trace {
  1291:			defer un(trace(p, "StatementList"))
  1292:		}
  1293:
=>1294:		for p.tok != token.CASE && p.tok != token.DEFAULT && p.tok != token.RBRACE && p.tok != token.EOF {
  1295:			list = append(list, p.parseStmt())
  1296:		}
  1297:
  1298:		return
  1299:	}
(dlv) bt
 0  0x0000000001407991 in github.com/goplus/gop/parser.(*parser).parseStmtList
    at goplus/src/github.com/goplus/gop/parser/parser.go:1294
 1  0x0000000001407d05 in github.com/goplus/gop/parser.(*parser).parseBody
    at goplus/src/github.com/goplus/gop/parser/parser.go:1309
 2  0x000000000141900b in github.com/goplus/gop/parser.(*parser).parseFuncDecl
    at goplus/src/github.com/goplus/gop/parser/parser.go:3075
 3  0x0000000001419734 in github.com/goplus/gop/parser.(*parser).parseDecl
    at goplus/src/github.com/goplus/gop/parser/parser.go:3133
 4  0x000000000141a5a6 in github.com/goplus/gop/parser.(*parser).parseFile
    at goplus/src/github.com/goplus/gop/parser/parser.go:3196
 5  0x00000000013fcbc5 in github.com/goplus/gop/parser.parseFile
    at goplus/src/github.com/goplus/gop/parser/interface.go:108
 6  0x000000000141ce8e in github.com/goplus/gop/parser.parseFileEx
    at goplus/src/github.com/goplus/gop/parser/parser_gop.go:273
 7  0x000000000141c107 in github.com/goplus/gop/parser.parseFSFileEx
    at goplus/src/github.com/goplus/gop/parser/parser_gop.go:222
 8  0x000000000141bcaa in github.com/goplus/gop/parser.ParseFSFile
    at goplus/src/github.com/goplus/gop/parser/parser_gop.go:206
 9  0x000000000141ba97 in github.com/goplus/gop/parser.ParseFile
    at goplus/src/github.com/goplus/gop/parser/parser_gop.go:196
10  0x000000000141ab8f in github.com/goplus/gop/parser.Parse
    at goplus/src/github.com/goplus/gop/parser/parser_gop.go:80
11  0x000000000148109e in github.com/goplus/gop/cmd/internal/run.runCmd
    at goplus/src/github.com/goplus/gop/cmd/internal/run/run.go:172
12  0x0000000001485234 in main.main
    at goplus/gop-1.0.16/cmd/gop/main.go:95
13  0x0000000001038433 in runtime.main
    at /usr/local/Cellar/go/1.17.2/libexec/src/runtime/proc.go:255
14  0x0000000001066601 in runtime.goexit
    at /usr/local/Cellar/go/1.17.2/libexec/src/runtime/asm_amd64.s:1581
(dlv)
```

开始逐步处理语句，返回的 AST 节点对象压入 list

```bash
goplus/src/github.com/goplus/gop/parser/parser.go:1295 (PC: 0x1407a29)
  1290:		if p.trace {
  1291:			defer un(trace(p, "StatementList"))
  1292:		}
  1293:
  1294:		for p.tok != token.CASE && p.tok != token.DEFAULT && p.tok != token.RBRACE && p.tok != token.EOF {
=>1295:			list = append(list, p.parseStmt())
  1296:		}
  1297:
  1298:		return
  1299:	}
```

看下单条语句的解析处理

```bash
goplus/src/github.com/goplus/gop/parser/parser.go:2843 (PC: 0x1416d13)
  2838:		}
  2839:
  2840:		switch p.tok {
  2841:		case token.CONST, token.TYPE, token.VAR:
  2842:			s = &ast.DeclStmt{Decl: p.parseDecl(stmtStart)}
=>2843:		case
  2844:			// tokens that may start an expression
  2845:			token.IDENT, token.INT, token.FLOAT, token.IMAG, token.RAT, token.CHAR, token.STRING, token.FUNC, token.LPAREN, // operands
  2846:			token.LBRACK, token.STRUCT, token.MAP, token.CHAN, token.INTERFACE, // composite types
  2847:			token.ADD, token.SUB, token.MUL, token.AND, token.XOR, token.ARROW, token.NOT: // unary operators
  2848:			s, _ = p.parseSimpleStmt(labelOk)
(dlv) n
> github.com/goplus/gop/parser.(*parser).parseStmt() goplus/src/github.com/goplus/gop/parser/parser.go:2848 (PC: 0x14171d6)
  2843:		case
  2844:			// tokens that may start an expression
  2845:			token.IDENT, token.INT, token.FLOAT, token.IMAG, token.RAT, token.CHAR, token.STRING, token.FUNC, token.LPAREN, // operands
  2846:			token.LBRACK, token.STRUCT, token.MAP, token.CHAN, token.INTERFACE, // composite types
  2847:			token.ADD, token.SUB, token.MUL, token.AND, token.XOR, token.ARROW, token.NOT: // unary operators
=>2848:			s, _ = p.parseSimpleStmt(labelOk)
  2849:			// because of the required look-ahead, labeled statements are
  2850:			// parsed by parseSimpleStmt - don't expect a semicolon after
  2851:			// them
  2852:			if _, isLabeledStmt := s.(*ast.LabeledStmt); !isLabeledStmt {
  2853:				p.expectSemi()
```

看下解析返回的结构 

```bash
(dlv) p s
github.com/goplus/gop/ast.Stmt(*github.com/goplus/gop/ast.ExprStmt) *{
	X: github.com/goplus/gop/ast.Expr(*github.com/goplus/gop/ast.CallExpr) *{
		Fun: github.com/goplus/gop/ast.Expr(*github.com/goplus/gop/ast.Ident) ...,
		Lparen: 34,
		Args: []github.com/goplus/gop/ast.Expr len: 1, cap: 1, [
			...,
		],
		Ellipsis: NoPos (0),
		Rparen: 50,
		NoParenEnd: NoPos (0),},}
```

构造一个 ast.BlockStmt 返回

```bash
=>1310:		p.closeLabelScope()
  1311:		p.closeScope()
  1312:		rbrace := p.expect2(token.RBRACE)
  1313:
  1314:		return &ast.BlockStmt{Lbrace: lbrace, List: list, Rbrace: rbrace}
  1315:	}
(dlv) p list
[]github.com/goplus/gop/ast.Stmt len: 1, cap: 1, [
	*github.com/goplus/gop/ast.ExprStmt {
		X: github.com/goplus/gop/ast.Expr(*github.com/goplus/gop/ast.CallExpr) ...,},
]
```

构造一个 ast.FuncDecl 返回

```bash
goplus/src/github.com/goplus/gop/parser/parser.go:3090 (PC: 0x14190f0)
  3085:		} else {
  3086:			p.expectSemi()
  3087:		}
  3088:
  3089:		decl := &ast.FuncDecl{
=>3090:			Doc:  doc,
  3091:			Recv: recv,
  3092:			Name: ident,
  3093:			Type: &ast.FuncType{
  3094:				Func:    pos,
  3095:				Params:  params,

goplus/src/github.com/goplus/gop/parser/parser.go:3098 (PC: 0x1419227)
  3093:			Type: &ast.FuncType{
  3094:				Func:    pos,
  3095:				Params:  params,
  3096:				Results: results,
  3097:			},
=>3098:			Body:     body,
  3099:			Operator: isOp,
  3100:		}
  3101:		if recv == nil {
  3102:			// Go spec: The scope of an identifier denoting a constant, type,
  3103:			// variable, or function (but not method) declared at top level
```

看下函数体 body 的内容，可以看到 println("Hello, world!") 的相关信息

```bash
dlv) p body
*github.com/goplus/gop/ast.BlockStmt {
	Lbrace: 26,
	List: []github.com/goplus/gop/ast.Stmt len: 1, cap: 1, [
		...,
	],
	Rbrace: 53,}

(dlv) p body.List[0]
github.com/goplus/gop/ast.Stmt(*github.com/goplus/gop/ast.ExprStmt) *{
	X: github.com/goplus/gop/ast.Expr(*github.com/goplus/gop/ast.CallExpr) *{
		Fun: github.com/goplus/gop/ast.Expr(*github.com/goplus/gop/ast.Ident) ...,
		Lparen: 34,
		Args: []github.com/goplus/gop/ast.Expr len: 1, cap: 1, [
			...,
		],
		Ellipsis: NoPos (0),
		Rparen: 50,
		NoParenEnd: NoPos (0),},}

(dlv) p body.List[0].X
github.com/goplus/gop/ast.Expr(*github.com/goplus/gop/ast.CallExpr) *{
	Fun: github.com/goplus/gop/ast.Expr(*github.com/goplus/gop/ast.Ident) *{
		NamePos: 27,
		Name: "println",
		Obj: *(*"github.com/goplus/gop/ast.Object")(0xc000137400),},
	Lparen: 34,
	Args: []github.com/goplus/gop/ast.Expr len: 1, cap: 1, [
		...,
	],
	Ellipsis: NoPos (0),
	Rparen: 50,
	NoParenEnd: NoPos (0),}

(dlv) p body.List[0].X.Args[0]
github.com/goplus/gop/ast.Expr(*github.com/goplus/gop/ast.BasicLit) *{
	ValuePos: 35,
	Kind: STRING (9),
	Value: "\"Hello, world!\"",}
(dlv)
```

goplus/src/github.com/goplus/gop/parser/parser.go:1314 (PC: 0x1407d4e)
  1309:		list := p.parseStmtList()
  1310:		p.closeLabelScope()
  1311:		p.closeScope()
  1312:		rbrace := p.expect2(token.RBRACE)
  1313:
=>1314:		return &ast.BlockStmt{Lbrace: lbrace, List: list, Rbrace: rbrace}
  1315:	}
```

​```bash
goplus/src/github.com/goplus/gop/parser/parser.go:3109 (PC: 0x1419352)
  3104:			// (outside any function) is the package block.
  3105:			//
  3106:			// init() functions cannot be referred to and there may
  3107:			// be more than one - don't put them in the pkgScope
  3108:			if ident.Name != "init" {
=>3109:				p.declare(decl, nil, p.pkgScope, ast.Fun, ident)
  3110:			}
  3111:		}
```

```bash
goplus/src/github.com/goplus/gop/parser/parser.go:133 (PC: 0x13fd861)
   128:		p.targetStack = p.targetStack[0:n]
   129:		p.labelScope = p.labelScope.Outer
   130:	}
   131:
   132:	func (p *parser) declare(decl, data interface{}, scope *ast.Scope, kind ast.ObjKind, idents ...*ast.Ident) {
=> 133:		for _, ident := range idents {
   134:			assert(ident.Obj == nil, "identifier already declared or resolved")
   135:			obj := ast.NewObj(kind, ident.Name)
   136:			// remember the corresponding declaration for redeclaration
   137:			// errors and global variable resolution/typechecking phase
   138:			obj.Decl = decl
(dlv) bt
 0  0x00000000013fd861 in github.com/goplus/gop/parser.(*parser).declare
    at goplus/src/github.com/goplus/gop/parser/parser.go:133
 1  0x0000000001419411 in github.com/goplus/gop/parser.(*parser).parseFuncDecl
    at goplus/src/github.com/goplus/gop/parser/parser.go:3109
 2  0x0000000001419734 in github.com/goplus/gop/parser.(*parser).parseDecl
    at goplus/src/github.com/goplus/gop/parser/parser.go:3133
 3  0x000000000141a5a6 in github.com/goplus/gop/parser.(*parser).parseFile
    at goplus/src/github.com/goplus/gop/parser/parser.go:3196
 4  0x00000000013fcbc5 in github.com/goplus/gop/parser.parseFile
    at goplus/src/github.com/goplus/gop/parser/interface.go:108
 5  0x000000000141ce8e in github.com/goplus/gop/parser.parseFileEx
    at goplus/src/github.com/goplus/gop/parser/parser_gop.go:273
 6  0x000000000141c107 in github.com/goplus/gop/parser.parseFSFileEx
    at goplus/src/github.com/goplus/gop/parser/parser_gop.go:222
 7  0x000000000141bcaa in github.com/goplus/gop/parser.ParseFSFile
    at goplus/src/github.com/goplus/gop/parser/parser_gop.go:206
 8  0x000000000141ba97 in github.com/goplus/gop/parser.ParseFile
    at goplus/src/github.com/goplus/gop/parser/parser_gop.go:196
 9  0x000000000141ab8f in github.com/goplus/gop/parser.Parse
    at goplus/src/github.com/goplus/gop/parser/parser_gop.go:80
10  0x000000000148109e in github.com/goplus/gop/cmd/internal/run.runCmd
    at goplus/src/github.com/goplus/gop/cmd/internal/run/run.go:172
11  0x0000000001485234 in main.main
    at goplus/gop-1.0.16/cmd/gop/main.go:95
12  0x0000000001038433 in runtime.main
    at /usr/local/Cellar/go/1.17.2/libexec/src/runtime/proc.go:255
13  0x0000000001066601 in runtime.goexit
    at /usr/local/Cellar/go/1.17.2/libexec/src/runtime/asm_amd64.s:1581
```

```bash
goplus/src/github.com/goplus/gop/parser/parser.go:141 (PC: 0x13fd9b4)
   136:			// remember the corresponding declaration for redeclaration
   137:			// errors and global variable resolution/typechecking phase
   138:			obj.Decl = decl
   139:			obj.Data = data
   140:			ident.Obj = obj
=> 141:			if ident.Name != "_" {
   142:				if alt := scope.Insert(obj); alt != nil && p.mode&DeclarationErrors != 0 {
   143:					prevDecl := ""
   144:					if pos := alt.Pos(); pos.IsValid() {
   145:						prevDecl = fmt.Sprintf("\n\tprevious declaration at %s", p.file.Position(pos))
   146:					}

(dlv) p decl
interface {}(*github.com/goplus/gop/ast.FuncDecl) *{
	Doc: *github.com/goplus/gop/ast.CommentGroup nil,
	Recv: *github.com/goplus/gop/ast.FieldList nil,
	Name: *github.com/goplus/gop/ast.Ident {
		NamePos: 20,
		Name: "main",
		Obj: *(*"github.com/goplus/gop/ast.Object")(0xc0001374a0),},
	Type: *github.com/goplus/gop/ast.FuncType {
		Func: 15,
		Params: *(*"github.com/goplus/gop/ast.FieldList")(0xc000114ed0),
		Results: *github.com/goplus/gop/ast.FieldList nil,},
	Body: *github.com/goplus/gop/ast.BlockStmt {
		Lbrace: 26,
		List: []github.com/goplus/gop/ast.Stmt len: 1, cap: 1, [
			...,
		],
		Rbrace: 53,},
	Operator: false,}
(dlv) p data
interface {} nil
```

```bash
goplus/src/github.com/goplus/gop/parser/parser.go:3138 (PC: 0x14197b7)
  3133:			decl := p.parseFuncDecl()
  3134:			if p.errors.Len() != 0 {
  3135:				p.errorExpected(pos, "declaration", 2)
  3136:				p.advance(sync)
  3137:			}
=>3138:			return decl
  3139:		default:
  3140:			p.errorExpected(pos, "declaration", 2)
  3141:			p.advance(sync)
  3142:			return &ast.BadDecl{From: pos, To: p.pos}
  3143:		}
(dlv) p decl
*github.com/goplus/gop/ast.FuncDecl {
	Doc: *github.com/goplus/gop/ast.CommentGroup nil,
	Recv: *github.com/goplus/gop/ast.FieldList nil,
	Name: *github.com/goplus/gop/ast.Ident {
		NamePos: 20,
		Name: "main",
		Obj: *(*"github.com/goplus/gop/ast.Object")(0xc0001374a0),},
	Type: *github.com/goplus/gop/ast.FuncType {
		Func: 15,
		Params: *(*"github.com/goplus/gop/ast.FieldList")(0xc000114ed0),
		Results: *github.com/goplus/gop/ast.FieldList nil,},
	Body: *github.com/goplus/gop/ast.BlockStmt {
		Lbrace: 26,
		List: []github.com/goplus/gop/ast.Stmt len: 1, cap: 1, [
			...,
		],
		Rbrace: 53,},
	Operator: false,}
```

语法解析构建返回根节点 ast.File

```bash
goplus/src/github.com/goplus/gop/parser/parser.go:3216 (PC: 0x141a04a)
  3211:				p.unresolved[i] = ident
  3212:				i++
  3213:			}
  3214:		}
  3215:
=>3216:		
  3217:
  3218:		return &ast.File{
  3219:			Doc:        doc,
  3220:			Package:    pos,
  3221:			Name:       ident,

(dlv) p ident
*github.com/goplus/gop/ast.Ident {
	NamePos: 9,
	Name: "main",
	Obj: *github.com/goplus/gop/ast.Object nil,}

(dlv) p decls
[]github.com/goplus/gop/ast.Decl len: 1, cap: 1, [
	*github.com/goplus/gop/ast.FuncDecl {
		Doc: *github.com/goplus/gop/ast.CommentGroup nil,
		Recv: *github.com/goplus/gop/ast.FieldList nil,
		Name: *(*"github.com/goplus/gop/ast.Ident")(0xc0001444e0),
		Type: *(*"github.com/goplus/gop/ast.FuncType")(0xc000122198),
		Body: *(*"github.com/goplus/gop/ast.BlockStmt")(0xc000114f30),
		Operator: false,},
]
```

源码解析完成，返回 AST 抽象语法树, ast.File


```bash
goplus/src/github.com/goplus/gop/parser/interface.go:110 (PC: 0x13fcbcd)
   105:
   106:		// parse source
   107:		p.init(fset, filename, text, mode)
   108:		f = p.parseFile()
   109:
=> 110:		return
   111:	}
   112:
   113:	/*
   114:	// ParseExprFrom is a convenience function for parsing an expression.
   115:	// The arguments have the same meaning as for ParseFile, but the source must
(dlv) p f
*github.com/goplus/gop/ast.File {
	Doc: *github.com/goplus/gop/ast.CommentGroup nil,
	Package: github.com/goplus/gox.InstrFlagEllipsis (1),
	Name: *github.com/goplus/gop/ast.Ident {
		NamePos: 9,
		Name: "main",
		Obj: *github.com/goplus/gop/ast.Object nil,},
	Decls: []github.com/goplus/gop/ast.Decl len: 1, cap: 1, [
		...,
	],
	Scope: *github.com/goplus/gop/ast.Scope {
		Outer: *github.com/goplus/gop/ast.Scope nil,
		Objects: map[string]*github.com/goplus/gop/ast.Object [...],},
	Imports: []*github.com/goplus/gop/ast.ImportSpec len: 0, cap: 0, nil,
	Unresolved: []*github.com/goplus/gop/ast.Ident len: 1, cap: 1, [
		*(*"github.com/goplus/gop/ast.Ident")(0xc000144500),
	],
	Comments: []*github.com/goplus/gop/ast.CommentGroup len: 0, cap: 0, nil,
	Code: []uint8 len: 0, cap: 0, nil,
	NoEntrypoint: false,
	NoPkgDecl: false,
	FileType: 0,}
(dlv)
```


```bash
goplus/src/github.com/goplus/gop/parser/parser_gop.go:85 (PC: 0x141abf7)
    80:		file, err := ParseFile(fset, target, src, mode)
    81:		if err != nil {
    82:			return
    83:		}
    84:
=>  85:		到这里说明 go 语法补齐，go 语法树生成完毕
    86:
    87:		pkgs = make(map[string]*ast.Package)
    88:		pkgs[file.Name.Name] = astFileToPkg(file, target)
    89:		return
```

把返回的 ast.File 和 package 信息关联

```bash
goplus/src/github.com/goplus/gop/parser/parser_gop.go:93 (PC: 0x141adca)
    88:		pkgs[file.Name.Name] = astFileToPkg(file, target)
    89:		return
    90:	}
    91:
    92:	// astFileToPkg translate ast.File to ast.Package
=>  93:	func astFileToPkg(file *ast.File, fileName string) (pkg *ast.Package) {
    94:		pkg = &ast.Package{
    95:			Name:  file.Name.Name,
    96:			Files: make(map[string]*ast.File),
    97:		}
    98:		pkg.Files[fileName] = file
(dlv) bt
0  0x000000000141adca in github.com/goplus/gop/parser.astFileToPkg
   at goplus/src/github.com/goplus/gop/parser/parser_gop.go:93
1  0x000000000141ace5 in github.com/goplus/gop/parser.Parse
   at goplus/src/github.com/goplus/gop/parser/parser_gop.go:88
2  0x000000000148109e in github.com/goplus/gop/cmd/internal/run.runCmd
   at goplus/src/github.com/goplus/gop/cmd/internal/run/run.go:172
3  0x0000000001485234 in main.main
   at goplus/gop-1.0.16/cmd/gop/main.go:95
4  0x0000000001038433 in runtime.main
   at /usr/local/Cellar/go/1.17.2/libexec/src/runtime/proc.go:255
5  0x0000000001066601 in runtime.goexit
   at /usr/local/Cellar/go/1.17.2/libexec/src/runtime/asm_amd64.s:1581
```

创建 ast.Package 对象，可以看到进入列表 pkg.Files[fileName] = file
一个 package 有多个源文件，一个源文件对应一个 ast.File 语法树

```bash
goplus/src/github.com/goplus/gop/parser/parser_gop.go:96 (PC: 0x141adf0)
    91:
    92:	// astFileToPkg translate ast.File to ast.Package
    93:	func astFileToPkg(file *ast.File, fileName string) (pkg *ast.Package) {
    94:		pkg = &ast.Package{
    95:			Name:  file.Name.Name,
=>  96:			Files: make(map[string]*ast.File),
    97:		}
    98:		pkg.Files[fileName] = file
    99:		return
   100:	}
   101:
(dlv) p fileName
"goplus...+22 more"
(dlv) p file.Name
*github.com/goplus/gop/ast.Ident {
	NamePos: 9,
	Name: "main",
	Obj: *github.com/goplus/gop/ast.Object nil,}
(dlv) p file.Name.Name
"main"
```

源码解析后返回一个 package 对象列表

```bash
goplus/src/github.com/goplus/gop/cmd/internal/run/run.go:172 (PC: 0x148109e)
Values returned:
	pkgs: map[string]*github.com/goplus/gop/ast.Package [
		"main": *{
			Name: "main",
			Scope: *github.com/goplus/gop/ast.Scope nil,
			Imports: map[string]*github.com/goplus/gop/ast.Object nil,
			Files: map[string]*github.com/goplus/gop/ast.File [...],},
	]
	err: error nil

   167:					pkgs, err = parser.Parse(fset, src, nil, 0)
   168:				} else {
   169:					
   170:				
   171:					// pkgs 是解析后返回的“包”的列表
=> 172:					pkgs, err = parser.Parse(fset, src, nil, 0) // TODO: only to check dependencies
   173:				}
   174:			} else if *flagNorun {
   175:				return
   176:			}
   177:		}
```

### 编译阶段

对 main package 的处理 

```bash
goplus/src/github.com/goplus/gop/cmd/internal/run/run.go:221 (PC: 0x148171c)
   216:				os.Exit(12)
   217:			}
   218:
   219:			modDir, noCacheFile := findGoModDir(srcDir)
   220:			fmt.Println("[debug], go modDir: ", modDir) // for debug
=> 221:			conf := &cl.Config{
   222:				Dir: modDir, TargetDir: srcDir, Fset: fset, CacheLoadPkgs: true, PersistLoadPkgs: !noCacheFile}
   223:			// 返回 out 是 Go 的 DOM Writer
   224:			out, err := cl.NewPackage("", mainPkg, conf) // 编译 AST 语法树
   225:			if err != nil {
   226:				fmt.Fprintln(os.Stderr, err)
(dlv) n
> github.com/goplus/gop/cmd/internal/run.runCmd() goplus/src/github.com/goplus/gop/cmd/internal/run/run.go:224 (PC: 0x148172c)
   219:			modDir, noCacheFile := findGoModDir(srcDir)
   220:			fmt.Println("[debug], go modDir: ", modDir) // for debug
   221:			conf := &cl.Config{
   222:				Dir: modDir, TargetDir: srcDir, Fset: fset, CacheLoadPkgs: true, PersistLoadPkgs: !noCacheFile}
   223:			// 返回 out 是 Go 的 DOM Writer
=> 224:			out, err := cl.NewPackage("", mainPkg, conf) // 编译 AST 语法树
   225:			if err != nil {
   226:				fmt.Fprintln(os.Stderr, err)
   227:				os.Exit(11)
   228:			}
```

进入 AST 语法树的编译处理阶段，一般后续的是做语义分析和语法查错，编程成中间代码，汇编代码等

```bash
goplus/src/github.com/goplus/gop/cl/compile.go:391 (PC: 0x143682a)
   387:	func NewPackage(pkgPath string, pkg *ast.Package, conf *Config) (p *gox.Package, err error) {
   388:
   389:		fmt.Println("[debug] compile NewPackage: ", pkgPath) // for debug
   390:
=> 391:		conf = conf.Ensure()
   392:		dir := conf.Dir
   393:		if dir == "" {
   394:			dir, _ = os.Getwd()
   395:		}
   396:		workingDir := conf.WorkingDir
(dlv) bt
0  0x000000000143682a in github.com/goplus/gop/cl.NewPackage
   at goplus/src/github.com/goplus/gop/cl/compile.go:391
1  0x000000000148175a in github.com/goplus/gop/cmd/internal/run.runCmd
   at goplus/src/github.com/goplus/gop/cmd/internal/run/run.go:224
2  0x0000000001485234 in main.main
   at goplus/gop-1.0.16/cmd/gop/main.go:95
3  0x0000000001038433 in runtime.main
   at /usr/local/Cellar/go/1.17.2/libexec/src/runtime/proc.go:255
4  0x0000000001066601 in runtime.goexit
   at /usr/local/Cellar/go/1.17.2/libexec/src/runtime/asm_amd64.s:1581
```

去调用 gox 模块的做对 AST 后续 的处理

```bash
goplus/src/github.com/goplus/gop/cl/compile.go:421 (PC: 0x1436ec1)
   416:			HandleErr:       ctx.handleErr,
   417:			NodeInterpreter: interp,
   418:			ParseFile:       nil, // TODO
   419:			NewBuiltin:      newBuiltinDefault,
   420:		}
=> 421:		p = gox.NewPackage(pkgPath, pkg.Name, confGox)
   422:		for file, gmx := range pkg.Files {
   423:			if gmx.FileType == ast.FileTypeGmx {
   424:				ctx.gmxSettings = newGmx(p, file)
   425:				break
```

看下调用栈

```bash
goplus/src/github.com/goplus/gox/package.go:332 (PC: 0x13bc59d)
   327:	// NewPackage creates a new package.
   328:	func NewPackage(pkgPath, name string, conf *Config) *Package {
   329:		if conf == nil {
   330:			conf = &Config{}
   331:		}
=> 332:		newBuiltin := conf.NewBuiltin
   333:		if newBuiltin == nil {
   334:			newBuiltin = newBuiltinDefault
   335:		}
   336:		loadPkgs := conf.LoadPkgs
   337:		if loadPkgs == nil {
(dlv) bt
0  0x00000000013bc59d in github.com/goplus/gox.NewPackage
   at goplus/src/github.com/goplus/gox/package.go:332
1  0x0000000001436eff in github.com/goplus/gop/cl.NewPackage
   at goplus/src/github.com/goplus/gop/cl/compile.go:421
2  0x000000000148175a in github.com/goplus/gop/cmd/internal/run.runCmd
   at goplus/src/github.com/goplus/gop/cmd/internal/run/run.go:224
3  0x0000000001485234 in main.main
   at goplus/gop-1.0.16/cmd/gop/main.go:95
4  0x0000000001038433 in runtime.main
   at /usr/local/Cellar/go/1.17.2/libexec/src/runtime/proc.go:255
5  0x0000000001066601 in runtime.goexit
   at /usr/local/Cellar/go/1.17.2/libexec/src/runtime/asm_amd64.s:1581
```

做一层 package 的封装, 操作 AST 数据结构的调整和转换

```bash
/goplus/src/github.com/goplus/gox/package.go:348 (PC: 0x13bc74e)
   343:		}
   344:		pkg := &Package{
   345:			Fset:     conf.Fset,
   346:			files:    files,
   347:			conf:     conf,
=> 348:			modPath:  conf.ModPath,
   349:			loadPkgs: loadPkgs,
   350:		}
   351:		pkg.Types = types.NewPackage(pkgPath, name) // 调用 go/types 库
   352:		pkg.builtin = newBuiltin(pkg, conf)
   353:		pkg.utBigInt = conf.UntypedBigInt
```

初始化了 pkg.cb ，这是个代码生成器，

```bash
goplus/src/github.com/goplus/gox/package.go:357 (PC: 0x13bc92c)
   352:		pkg.builtin = newBuiltin(pkg, conf)
   353:		pkg.utBigInt = conf.UntypedBigInt
   354:		pkg.utBigRat = conf.UntypedBigRat
   355:		pkg.utBigFlt = conf.UntypedBigFloat
   356:		pkg.cb.init(pkg)
=> 357:		return pkg
   358:	}

(dlv) p pkg.cb
github.com/goplus/gox.CodeBuilder {
	stk: github.com/goplus/gox/internal.Stack {
		data: []*github.com/goplus/gox/internal.Elem len: 0, cap: 64, [],},
	current: github.com/goplus/gox.funcBodyCtx {
		codeBlockCtx: (*"github.com/goplus/gox.codeBlockCtx")(0xc000df0de8),
		fn: *github.com/goplus/gox.Func nil,
		labels: map[string]*github.com/goplus/gox.Label nil,},
	comments: *go/ast.CommentGroup nil,
	pkg: *github.com/goplus/gox.Package {
		PkgRef: (*"github.com/goplus/gox.PkgRef")(0xc000df0d80),
		cb: (*"github.com/goplus/gox.CodeBuilder")(0xc000df0dd0),
		files: [2]github.com/goplus/gox.file [
			(*"github.com/goplus/gox.file")(0xc000df0e90),
			(*"github.com/goplus/gox.file")(0xc000df0ef8),
		],
		conf: *(*"github.com/goplus/gox.Config")(0xc00087db00),
		modPath: "",
		Fset: *(*"go/token.FileSet")(0xc00012e800),
		builtin: *(*"go/types.Package")(0xc000e22d70),
		utBigInt: *(*"go/types.Named")(0xc000c1c280),
		utBigRat: *(*"go/types.Named")(0xc000c1c300),
		utBigFlt: *(*"go/types.Named")(0xc000c1c200),
		loadPkgs: github.com/goplus/gox.(*LoadPkgsCached).Load-fm,
		autoIdx: 0,
		testingFile: 0,
		commentedStmts: map[go/ast.Stmt]*go/ast.CommentGroup nil,},
	varDecl: *github.com/goplus/gox.ValueDecl nil,
	interp: github.com/goplus/gox.NodeInterpreter(*github.com/goplus/gop/cl.nodeInterp) *{
		fset: *(*"go/token.FileSet")(0xc00012e800),
		files: map[string]*github.com/goplus/gop/ast.File [...],
		workingDir: "goplus...+12 more",},
	loadNamed: github.com/goplus/gop/cl.(*pkgCtx).loadNamed-fm,
	handleErr: github.com/goplus/gop/cl.(*pkgCtx).handleErr-fm,
	closureParamInsts: github.com/goplus/gox.closureParamInsts {
		paramInsts: map[github.com/goplus/gox.closureParamInst]*go/types.Var [],},
	iotav: 0,
	commentOnce: false,}
```

```bash
goplus/src/github.com/goplus/gop/cl/compile.go:596 (PC: 0x1438c75)
   591:						parent.inits = append(parent.inits, fn)
   592:					} else {
   593:						if debugLoad {
   594:							log.Println("==> Preload func", name.Name)
   595:						}
=> 596:						initLoader(parent, syms, name.Pos(), name.Name, fn)
   597:					}
   598:				} else {
   599:					if name, ok := getRecvTypeName(parent, d.Recv, true); ok {
   600:						if debugLoad {
   601:							log.Printf("==> Preload method %s.%s\n", name, d.Name.Name)
(dlv) bt
0  0x0000000001438c75 in github.com/goplus/gop/cl.preloadFile
   at goplus/src/github.com/goplus/gop/cl/compile.go:596
1  0x00000000014370f5 in github.com/goplus/gop/cl.NewPackage
   at goplus/src/github.com/goplus/gop/cl/compile.go:429
2  0x000000000148175a in github.com/goplus/gop/cmd/internal/run.runCmd
   at goplus/src/github.com/goplus/gop/cmd/internal/run/run.go:224
3  0x0000000001485234 in main.main
   at goplus/gop-1.0.16/cmd/gop/main.go:95
4  0x0000000001038433 in runtime.main
   at /usr/local/Cellar/go/1.17.2/libexec/src/runtime/proc.go:255
5  0x0000000001066601 in runtime.goexit
   at /usr/local/Cellar/go/1.17.2/libexec/src/runtime/asm_amd64.s:1581
```

```bash
/goplus/src/github.com/goplus/gop/cl/compile.go:218 (PC: 0x14351ef)
   213:			oldpos := ctx.Position(old.pos())
   214:			ctx.handleCodeErrorf(
   215:				&pos, "%s redeclared in this block\n\tprevious declaration at %v", name, oldpos)
   216:			return
   217:		}
=> 218:		syms[name] = &baseLoader{start: start, fn: fn}
   219:	}
   220:
   221:	func (p *baseLoader) load() {
   222:		p.fn()
   223:	}
(dlv) p name
"main"

(dlv) p fn
github.com/goplus/gop/cl.preloadFile.func2
(dlv) p start
20

```

```bash
goplus/src/github.com/goplus/gop/cl/compile.go:469 (PC: 0x1437759)
   464:	}
   465:
   466:	func loadFile(ctx *pkgCtx, f *ast.File) {
   467:		for _, decl := range f.Decls {
   468:			switch d := decl.(type) {
=> 469:			case *ast.FuncDecl:
   470:				if d.Recv == nil {
   471:					name := d.Name.Name
   472:					if name != "init" {
   473:						ctx.loadSymbol(name)
   474:					}
(dlv) p type
Command failed: 1:1: expected operand, found 'type'
(dlv) bt
0  0x0000000001437759 in github.com/goplus/gop/cl.loadFile
   at goplus/src/github.com/goplus/gop/cl/compile.go:469
1  0x0000000001437278 in github.com/goplus/gop/cl.NewPackage
   at goplus/src/github.com/goplus/gop/cl/compile.go:440
2  0x000000000148175a in github.com/goplus/gop/cmd/internal/run.runCmd
   at goplus/src/github.com/goplus/gop/cmd/internal/run/run.go:224
3  0x0000000001485234 in main.main
   at goplus/gop-1.0.16/cmd/gop/main.go:95
4  0x0000000001038433 in runtime.main
   at /usr/local/Cellar/go/1.17.2/libexec/src/runtime/proc.go:255
5  0x0000000001066601 in runtime.goexit
   at /usr/local/Cellar/go/1.17.2/libexec/src/runtime/asm_amd64.s:1581
```

```bash
goplus/src/github.com/goplus/gop/cl/compile.go:449 (PC: 0x1437399)
   444:			ld.load()
   445:		}
   446:		for _, load := range ctx.inits {
   447:			load()
   448:		}
=> 449:		err = ctx.complete()
   450:		return
   451:	}
   452:
```

### 生成  go 源码

**要把 out 的内容生成 go 源码文件**

```bash
goplus/src/github.com/goplus/gop/cmd/internal/run/run.go:230 (PC: 0x14818a2)
   225:			if err != nil {
   226:				fmt.Fprintln(os.Stderr, err)
   227:				os.Exit(11)
   228:			}
   229:
=> 230:			
   231:
   232:			// 生成和保存 go 源码文件
   233:			err = saveGoFile(gofile, out)
```
**out 对接，即 gox.Package 结构的情况** 

```bash
(dlv) p out
*github.com/goplus/gox.Package {
	PkgRef: github.com/goplus/gox.PkgRef {
		ID: "",
		Types: *(*"go/types.Package")(0xc000e22cd0),
		file: *github.com/goplus/gox.file nil,
		pkg: *github.com/goplus/gox.Package nil,
		pkgf: *github.com/goplus/gox.pkgFingerp nil,
		IllTyped: false,
		inTestingFile: false,
		isForceUsed: false,
		isUsed: false,
		nameRefs: []*go/ast.Ident len: 0, cap: 0, nil,},
	cb: github.com/goplus/gox.CodeBuilder {
		stk: (*"github.com/goplus/gox/internal.Stack")(0xc000df0dd0),
		current: (*"github.com/goplus/gox.funcBodyCtx")(0xc000df0de8),
		comments: *(*"go/ast.CommentGroup")(0xc000e24bb8),
		pkg: *(*"github.com/goplus/gox.Package")(0xc000df0d80),
		varDecl: *github.com/goplus/gox.ValueDecl nil,
		interp: github.com/goplus/gox.NodeInterpreter(*github.com/goplus/gop/cl.nodeInterp) ...,
		loadNamed: github.com/goplus/gop/cl.(*pkgCtx).loadNamed-fm,
		handleErr: github.com/goplus/gop/cl.(*pkgCtx).handleErr-fm,
		closureParamInsts: (*"github.com/goplus/gox.closureParamInsts")(0xc000df0e78),
		iotav: 0,
		commentOnce: false,},
	files: [2]github.com/goplus/gox.file [
		(*"github.com/goplus/gox.file")(0xc000df0e90),
		(*"github.com/goplus/gox.file")(0xc000df0ef8),
	],
	conf: *github.com/goplus/gox.Config {
		Context: context.Context nil,
		Logf: nil,
		Dir: "goplus...+12 more",
		ModPath: "",
		Env: []string len: 0, cap: 0, nil,
		BuildFlags: []string len: 0, cap: 0, nil,
		Fset: *(*"go/token.FileSet")(0xc00012e800),
		ParseFile: nil,
		HandleErr: github.com/goplus/gop/cl.(*pkgCtx).handleErr-fm,
		NodeInterpreter: github.com/goplus/gox.NodeInterpreter(*github.com/goplus/gop/cl.nodeInterp) ...,
		LoadPkgs: github.com/goplus/gox.(*LoadPkgsCached).Load-fm,
		LoadNamed: github.com/goplus/gop/cl.(*pkgCtx).loadNamed-fm,
		NewBuiltin: github.com/goplus/gop/cl.newBuiltinDefault,
		UntypedBigInt: *(*"go/types.Named")(0xc000c1c280),
		UntypedBigRat: *(*"go/types.Named")(0xc000c1c300),
		UntypedBigFloat: *(*"go/types.Named")(0xc000c1c200),},
	modPath: "",
	Fset: *go/token.FileSet {
		mutex: (*sync.RWMutex)(0xc00012e800),
		base: 55,
		files: []*go/token.File len: 1, cap: 1, [
			*(*"go/token.File")(0xc00012c5a0),
		],
		last: *(*"go/token.File")(0xc00012c5a0),},
	builtin: *go/types.Package {
		path: "",
		name: "",
		scope: *(*"go/types.Scope")(0xc000e22d20),
		complete: false,
		imports: []*go/types.Package len: 0, cap: 0, nil,
		fake: false,
		cgo: false,},
	utBigInt: *go/types.Named {
		check: *go/types.Checker nil,
		info: 0,
		obj: *(*"go/types.TypeName")(0xc000c23040),
		orig: go/types.Type nil,
		underlying: go/types.Type(*go/types.Pointer) ...,
		tparams: []*go/types.TypeName len: 0, cap: 0, nil,
		targs: []go/types.Type len: 0, cap: 0, nil,
		methods: []*go/types.Func len: 0, cap: 0, nil,},
	utBigRat: *go/types.Named {
		check: *go/types.Checker nil,
		info: 0,
		obj: *(*"go/types.TypeName")(0xc000c230e0),
		orig: go/types.Type nil,
		underlying: go/types.Type(*go/types.Pointer) ...,
		tparams: []*go/types.TypeName len: 0, cap: 0, nil,
		targs: []go/types.Type len: 0, cap: 0, nil,
		methods: []*go/types.Func len: 0, cap: 0, nil,},
	utBigFlt: *go/types.Named {
		check: *go/types.Checker nil,
		info: 0,
		obj: *(*"go/types.TypeName")(0xc000c22fa0),
		orig: go/types.Type nil,
		underlying: go/types.Type(*go/types.Pointer) ...,
		tparams: []*go/types.TypeName len: 0, cap: 0, nil,
		targs: []go/types.Type len: 0, cap: 0, nil,
		methods: []*go/types.Func len: 0, cap: 0, nil,},
	loadPkgs: github.com/goplus/gox.(*LoadPkgsCached).Load-fm,
	autoIdx: 0,
	testingFile: 0,
	commentedStmts: map[go/ast.Stmt]*go/ast.CommentGroup [
		...: *(*"go/ast.CommentGroup")(0xc000e24bb8),
	],}
```

**存 go 文件，最终会调用 gox 模块**

```
goplus/gop/cmd/internal/run/run.go:64 (PC: 0x147fc30)
    59:	func init() {
    60:		Cmd.Run = runCmd
    61:	}
    62:
    63:	func saveGoFile(gofile string, pkg *gox.Package) error {
=>  64:		dir := filepath.Dir(gofile)
    65:		err := os.MkdirAll(dir, 0755)
    66:		if err != nil {
    67:			return err
    68:		}
    69:		return gox.WriteFile(gofile, pkg, false)
(dlv) bt
0  0x000000000147fc30 in github.com/goplus/gop/cmd/internal/run.saveGoFile
   at goplus/src/github.com/goplus/gop/cmd/internal/run/run.go:64
1  0x0000000001481971 in github.com/goplus/gop/cmd/internal/run.runCmd
   at goplus/src/github.com/goplus/gop/cmd/internal/run/run.go:230
2  0x0000000001485234 in main.main
   at goplus/gop-1.0.16/cmd/gop/main.go:95
3  0x0000000001038433 in runtime.main
   at /usr/local/Cellar/go/1.17.2/libexec/src/runtime/proc.go:255
4  0x0000000001066601 in runtime.goexit
   at /usr/local/Cellar/go/1.17.2/libexec/src/runtime/asm_amd64.s:1581
```


**调用 gox 模块把 package 输出对应的 go 源码**

```bash
goplus/src/github.com/goplus/gox/gow.go:52 (PC: 0x13b5bb2)
    47:		return format.Node(dst, fset, CommentedASTFile(pkg, testingFile))
    48:	}
    49:
    50:	// WriteFile func
    51:	func WriteFile(file string, pkg *Package, testingFile bool) (err error) {
=>  52:		if debugWriteFile {
    53:			log.Println("WriteFile", file, "testing:", testingFile)
    54:		}
    55:		f, err := os.Create(file)
    56:		if err != nil {
    57:			return
(dlv) bt
0  0x00000000013b5bb2 in github.com/goplus/gox.WriteFile
   at goplus/src/github.com/goplus/gox/gow.go:52
1  0x000000000147fc9a in github.com/goplus/gop/cmd/internal/run.saveGoFile
   at goplus/src/github.com/goplus/gop/cmd/internal/run/run.go:69
2  0x0000000001481971 in github.com/goplus/gop/cmd/internal/run.runCmd
   at goplus/src/github.com/goplus/gop/cmd/internal/run/run.go:233
3  0x0000000001485234 in main.main
   at goplus/gop-1.0.16/cmd/gop/main.go:95
4  0x0000000001038433 in runtime.main
   at /usr/local/Cellar/go/1.17.2/libexec/src/runtime/proc.go:255
5  0x0000000001066601 in runtime.goexit
   at /usr/local/Cellar/go/1.17.2/libexec/src/runtime/asm_amd64.s:1581
```

**format.Node 是类似 go/format 格式输出 go AST 成源码的能力**

```bash
goplus/src/github.com/goplus/gox/gow.go:46 (PC: 0x13b5ab5)
    41:		}
    42:	}
    43:
    44:	// WriteTo func
    45:	func WriteTo(dst io.Writer, pkg *Package, testingFile bool) (err error) {
=>  46:		fset := token.NewFileSet()
    47:		return format.Node(dst, fset, CommentedASTFile(pkg, testingFile))
    48:	}
    49:
```



**做了一些封装，提取 package 对应声明 AST 语法树**

```bash
goplus/src/github.com/goplus/gox/gow.go:32 (PC: 0x13b580d)
    27:
    28:	// ----------------------------------------------------------------------------
    29:
    30:	// ASTFile func
    31:	func ASTFile(pkg *Package, testingFile bool) *ast.File {
=>  32:		idx := getInTestingFile(testingFile)
    33:		return &ast.File{Name: ident(pkg.Types.Name()), Decls: pkg.files[idx].getDecls(pkg)}
    34:	}
    35:
    36:	// CommentedASTFile func
    37:	func CommentedASTFile(pkg *Package, testingFile bool) *printer.CommentedNodes {
(dlv) bt
0  0x00000000013b580d in github.com/goplus/gox.ASTFile
   at goplus/src/github.com/goplus/gox/gow.go:32
1  0x00000000013b59d9 in github.com/goplus/gox.CommentedASTFile
   at goplus/src/github.com/goplus/gox/gow.go:39
2  0x00000000013b5ad1 in github.com/goplus/gox.WriteTo
   at goplus/src/github.com/goplus/gox/gow.go:47
3  0x00000000013b5ed9 in github.com/goplus/gox.WriteFile
   at goplus/src/github.com/goplus/gox/gow.go:66
4  0x000000000147fc9a in github.com/goplus/gop/cmd/internal/run.saveGoFile
   at goplus/src/github.com/goplus/gop/cmd/internal/run/run.go:69
5  0x0000000001481971 in github.com/goplus/gop/cmd/internal/run.runCmd
   at goplus/src/github.com/goplus/gop/cmd/internal/run/run.go:233
6  0x0000000001485234 in main.main
   at goplus/gop-1.0.16/cmd/gop/main.go:95
7  0x0000000001038433 in runtime.main
   at /usr/local/Cellar/go/1.17.2/libexec/src/runtime/proc.go:255
8  0x0000000001066601 in runtime.goexit
   at /usr/local/Cellar/go/1.17.2/libexec/src/runtime/asm_amd64.s:1581
```

```bash
goplus/src/github.com/goplus/gox/internal/go/format/format.go:58 (PC: 0x12a5643)
    53:	// and return a formatting error, for instance due to an incorrect AST.
    54:	//
    55:	func Node(dst io.Writer, fset *token.FileSet, node interface{}) error {
    56:		// Determine if we have a complete source file (file != nil).
    57:		var file *ast.File
=>  58:		var cnode *printer.CommentedNode
    59:		switch n := node.(type) {
    60:		case *ast.File:
    61:			file = n
    62:		case *printer.CommentedNode:
    63:			if f, ok := n.Node.(*ast.File); ok {
(dlv) bt
0  0x00000000012a5643 in github.com/goplus/gox/internal/go/format.Node
   at goplus/src/github.com/goplus/gox/internal/go/format/format.go:58
1  0x00000000013b5afa in github.com/goplus/gox.WriteTo
   at goplus/src/github.com/goplus/gox/gow.go:47
2  0x00000000013b5ed9 in github.com/goplus/gox.WriteFile
   at goplus/src/github.com/goplus/gox/gow.go:66
3  0x000000000147fc9a in github.com/goplus/gop/cmd/internal/run.saveGoFile
   at goplus/src/github.com/goplus/gop/cmd/internal/run/run.go:69
4  0x0000000001481971 in github.com/goplus/gop/cmd/internal/run.runCmd
   at goplus/src/github.com/goplus/gop/cmd/internal/run/run.go:233
5  0x0000000001485234 in main.main
   at goplus/gop-1.0.16/cmd/gop/main.go:95
6  0x0000000001038433 in runtime.main
   at /usr/local/Cellar/go/1.17.2/libexec/src/runtime/proc.go:255
7  0x0000000001066601 in runtime.goexit
   at /usr/local/Cellar/go/1.17.2/libexec/src/runtime/asm_amd64.s:1581
```

```bash
goplus/src/github.com/goplus/gox/gow.go:66 (PC: 0x13b5efa)
Values returned:

    61:			f.Close()
    62:			if err != nil {
    63:				os.Remove(file)
    64:			}
    65:		}()
=>  66:		return WriteTo(f, pkg, testingFile)
    67:	}
    68:
    69:	// ----------------------------------------------------------------------------
(dlv) bt
0  0x00000000013b5efa in github.com/goplus/gox.WriteFile
   at goplus/src/github.com/goplus/gox/gow.go:66
1  0x000000000147fc9a in github.com/goplus/gop/cmd/internal/run.saveGoFile
   at goplus/src/github.com/goplus/gop/cmd/internal/run/run.go:69
2  0x0000000001481971 in github.com/goplus/gop/cmd/internal/run.runCmd
   at goplus/src/github.com/goplus/gop/cmd/internal/run/run.go:233
3  0x0000000001485234 in main.main
   at goplus/gop-1.0.16/cmd/gop/main.go:95
4  0x0000000001038433 in runtime.main
   at /usr/local/Cellar/go/1.17.2/libexec/src/runtime/proc.go:255
5  0x0000000001066601 in runtime.goexit
   at /usr/local/Cellar/go/1.17.2/libexec/src/runtime/asm_amd64.s:1581
```







```
goplus/src/github.com/goplus/gox/gow.go:52 (PC: 0x13b5bb2)
    47:		return format.Node(dst, fset, CommentedASTFile(pkg, testingFile))
    48:	}
    49:
    50:	// WriteFile func
    51:	func WriteFile(file string, pkg *Package, testingFile bool) (err error) {
=>  52:		if debugWriteFile {
    53:			log.Println("WriteFile", file, "testing:", testingFile)
    54:		}
    55:		f, err := os.Create(file)
    56:		if err != nil {
    57:			return
(dlv) bt
0  0x00000000013b5bb2 in github.com/goplus/gox.WriteFile
   at goplus/src/github.com/goplus/gox/gow.go:52
1  0x000000000147fc9a in github.com/goplus/gop/cmd/internal/run.saveGoFile
   at goplus/src/github.com/goplus/gop/cmd/internal/run/run.go:69
2  0x0000000001481971 in github.com/goplus/gop/cmd/internal/run.runCmd
   at goplus/src/github.com/goplus/gop/cmd/internal/run/run.go:230
3  0x0000000001485234 in main.main
   at goplus/gop-1.0.16/cmd/gop/main.go:95
4  0x0000000001038433 in runtime.main
   at /usr/local/Cellar/go/1.17.2/libexec/src/runtime/proc.go:255
5  0x0000000001066601 in runtime.goexit
   at /usr/local/Cellar/go/1.17.2/libexec/src/runtime/asm_amd64.s:1581
```
```
goplus/src/github.com/goplus/gox/gow.go:66 (PC: 0x13b5eb0)
    61:			f.Close()
    62:			if err != nil {
    63:				os.Remove(file)
    64:			}
    65:		}()
=>  66:		return WriteTo(f, pkg, testingFile)
    67:	}
    68:
    69:	// ----------------------------------------------------------------------------
(dlv) p testingFile
false
(dlv) p pkg
*github.com/goplus/gox.Package {
	PkgRef: github.com/goplus/gox.PkgRef {
		ID: "",
		Types: *(*"go/types.Package")(0xc000ef4cd0),
		file: *github.com/goplus/gox.file nil,
		pkg: *github.com/goplus/gox.Package nil,
		pkgf: *github.com/goplus/gox.pkgFingerp nil,
		IllTyped: false,
		inTestingFile: false,
		isForceUsed: false,
		isUsed: false,
		nameRefs: []*go/ast.Ident len: 0, cap: 0, nil,},
	cb: github.com/goplus/gox.CodeBuilder {
		stk: (*"github.com/goplus/gox/internal.Stack")(0xc000ededd0),
		current: (*"github.com/goplus/gox.funcBodyCtx")(0xc000edede8),
		comments: *(*"go/ast.CommentGroup")(0xc000ef6ba0),
		pkg: *(*"github.com/goplus/gox.Package")(0xc000eded80),
		varDecl: *github.com/goplus/gox.ValueDecl nil,
		interp: github.com/goplus/gox.NodeInterpreter(*github.com/goplus/gop/cl.nodeInterp) ...,
		loadNamed: github.com/goplus/gop/cl.(*pkgCtx).loadNamed-fm,
		handleErr: github.com/goplus/gop/cl.(*pkgCtx).handleErr-fm,
		closureParamInsts: (*"github.com/goplus/gox.closureParamInsts")(0xc000edee78),
		iotav: 0,
		commentOnce: false,},
	files: [2]github.com/goplus/gox.file [
		(*"github.com/goplus/gox.file")(0xc000edee90),
		(*"github.com/goplus/gox.file")(0xc000edeef8),
	],
	conf: *github.com/goplus/gox.Config {
		Context: context.Context nil,
		Logf: nil,
		Dir: "goplus...+12 more",
		ModPath: "",
		Env: []string len: 0, cap: 0, nil,
		BuildFlags: []string len: 0, cap: 0, nil,
		Fset: *(*"go/token.FileSet")(0xc0000ba800),
		ParseFile: nil,
		HandleErr: github.com/goplus/gop/cl.(*pkgCtx).handleErr-fm,
		NodeInterpreter: github.com/goplus/gox.NodeInterpreter(*github.com/goplus/gop/cl.nodeInterp) ...,
		LoadPkgs: github.com/goplus/gox.(*LoadPkgsCached).Load-fm,
		LoadNamed: github.com/goplus/gop/cl.(*pkgCtx).loadNamed-fm,
		NewBuiltin: github.com/goplus/gop/cl.newBuiltinDefault,
		UntypedBigInt: *(*"go/types.Named")(0xc000e4b400),
		UntypedBigRat: *(*"go/types.Named")(0xc000e4b480),
		UntypedBigFloat: *(*"go/types.Named")(0xc000e4b380),},
	modPath: "",
	Fset: *go/token.FileSet {
		mutex: (*sync.RWMutex)(0xc0000ba800),
		base: 55,
		files: []*go/token.File len: 1, cap: 1, [
			*(*"go/token.File")(0xc0000b85a0),
		],
		last: *(*"go/token.File")(0xc0000b85a0),},
	builtin: *go/types.Package {
		path: "",
		name: "",
		scope: *(*"go/types.Scope")(0xc000ef4d20),
		complete: false,
		imports: []*go/types.Package len: 0, cap: 0, nil,
		fake: false,
		cgo: false,},
	utBigInt: *go/types.Named {
		check: *go/types.Checker nil,
		info: 0,
		obj: *(*"go/types.TypeName")(0xc000eab310),
		orig: go/types.Type nil,
		underlying: go/types.Type(*go/types.Pointer) ...,
		tparams: []*go/types.TypeName len: 0, cap: 0, nil,
		targs: []go/types.Type len: 0, cap: 0, nil,
		methods: []*go/types.Func len: 0, cap: 0, nil,},
	utBigRat: *go/types.Named {
		check: *go/types.Checker nil,
		info: 0,
		obj: *(*"go/types.TypeName")(0xc000eab3b0),
		orig: go/types.Type nil,
		underlying: go/types.Type(*go/types.Pointer) ...,
		tparams: []*go/types.TypeName len: 0, cap: 0, nil,
		targs: []go/types.Type len: 0, cap: 0, nil,
		methods: []*go/types.Func len: 0, cap: 0, nil,},
	utBigFlt: *go/types.Named {
		check: *go/types.Checker nil,
		info: 0,
		obj: *(*"go/types.TypeName")(0xc000eab270),
		orig: go/types.Type nil,
		underlying: go/types.Type(*go/types.Pointer) ...,
		tparams: []*go/types.TypeName len: 0, cap: 0, nil,
		targs: []go/types.Type len: 0, cap: 0, nil,
		methods: []*go/types.Func len: 0, cap: 0, nil,},
	loadPkgs: github.com/goplus/gox.(*LoadPkgsCached).Load-fm,
	autoIdx: 0,
	testingFile: 0,
	commentedStmts: map[go/ast.Stmt]*go/ast.CommentGroup [
		...: *(*"go/ast.CommentGroup")(0xc000ef6ba0),
	],}
(dlv)
```






### 调用 go run
**至此，hello.gop 对应的 go 文件 gop_autogen_hello.gop.go 已经生成完成**

```bash
goplus/src/github.com/goplus/gop/cmd/internal/run/run.go:242 (PC: 0x1481b1b)
   237:			conf.PkgsLoader.Save()
   238:		}
   239:
   240:		
   241:		// 调用 go run 执行 go 文件
=> 242:		goRun(gofile, args)
   243:		if *flagProf {
   244:			panic("TODO: profile not impl")
   245:		}
   246:	}
```

**构建 go run 命令，外部调用 go 执行对应的 go 文件**

```bash
goplus/src/github.com/goplus/gop/cmd/internal/run/run.go:254 (PC: 0x14824b1)
   249:		}
   250:		return fi.ModTime().After(fiDest.ModTime())
   251:	}
   252:
   253:	func goRun(file string, args []string) {
=> 254:		goArgs := make([]string, len(args)+2)
   255:		goArgs[0] = "run"
   256:		goArgs[1] = file
   257:		copy(goArgs[2:], args)
   258:		cmd := exec.Command("go", goArgs...)
   259:		cmd.Stdin = os.Stdin
(dlv) bt
0  0x00000000014824b1 in github.com/goplus/gop/cmd/internal/run.goRun
   at goplus/src/github.com/goplus/gop/cmd/internal/run/run.go:254
1  0x0000000001481b48 in github.com/goplus/gop/cmd/internal/run.runCmd
   at goplus/src/github.com/goplus/gop/cmd/internal/run/run.go:239
2  0x0000000001485234 in main.main
   at goplus/gop-1.0.16/cmd/gop/main.go:95
3  0x0000000001038433 in runtime.main
   at /usr/local/Cellar/go/1.17.2/libexec/src/runtime/proc.go:255
4  0x0000000001066601 in runtime.goexit
   at /usr/local/Cellar/go/1.17.2/libexec/src/runtime/asm_amd64.s:1581
(dlv)
```

**外部命令调用的封装**

```bash
goplus/src/github.com/goplus/gop/cmd/internal/run/run.go:258 (PC: 0x14825fb)
   253:	func goRun(file string, args []string) {
   254:		goArgs := make([]string, len(args)+2)
   255:		goArgs[0] = "run"
   256:		goArgs[1] = file
   257:		copy(goArgs[2:], args)
=> 258:		cmd := exec.Command("go", goArgs...)
   259:		cmd.Stdin = os.Stdin
   260:		cmd.Stdout = os.Stdout
   261:		cmd.Stderr = os.Stderr
   262:		cmd.Env = os.Environ()
   263:		err := cmd.Run()
(dlv) print args
[]string len: 0, cap: 0, []
(dlv) print goArgs
[]string len: 2, cap: 2, [
	"run",
	"goplus...+37 more",
]
(dlv)
```

**外部调用 go run 命令行**

```
> os/exec.(*Cmd).Run() /usr/local/Cellar/go/1.17.2/libexec/src/os/exec/exec.go:341 (PC: 0x1144193)
   336:	// process will inherit the caller's thread state.
   337:	func (c *Cmd) Run() error {
   338:		if err := c.Start(); err != nil {
   339:			return err
   340:		}
=> 341:		return c.Wait()
   342:	}
   343:
   344:	// lookExtensions finds windows executable by its dir and path.
   345:	// It uses LookPath to try appropriate extensions.
   346:	// lookExtensions does not search PATH, instead it converts `prog` into `.\prog`.
(dlv) bt
0  0x0000000001144193 in os/exec.(*Cmd).Run
   at /usr/local/Cellar/go/1.17.2/libexec/src/os/exec/exec.go:341
1  0x000000000148271b in github.com/goplus/gop/cmd/internal/run.goRun
   at goplus/src/github.com/goplus/gop/cmd/internal/run/run.go:263
2  0x0000000001481b48 in github.com/goplus/gop/cmd/internal/run.runCmd
   at goplus/src/github.com/goplus/gop/cmd/internal/run/run.go:239
3  0x0000000001485234 in main.main
   at goplus/gop-1.0.16/cmd/gop/main.go:95
4  0x0000000001038433 in runtime.main
   at /usr/local/Cellar/go/1.17.2/libexec/src/runtime/proc.go:255
5  0x0000000001066601 in runtime.goexit
   at /usr/local/Cellar/go/1.17.2/libexec/src/runtime/asm_amd64.s:1581
(dlv)
```

**go pacakge main.main 函数结束退出**

```
goplus/gop-1.0.16/cmd/gop/main.go:96 (PC: 0x1485234)
Values returned:

    91:				}
    92:				if !cmd.Runnable() {
    93:					continue
    94:				}
    95:				cmd.Run(cmd, args)
=>  96:				return
    97:			}
    98:			helpArg := ""
    99:			if i := strings.LastIndex(base.CmdName, " "); i >= 0 {
   100:				helpArg = " " + base.CmdName[:i]
   101:			}
(dlv) bt
0  0x0000000001485234 in main.main
   at goplus/gop-1.0.16/cmd/gop/main.go:96
1  0x0000000001038433 in runtime.main
   at /usr/local/Cellar/go/1.17.2/libexec/src/runtime/proc.go:255
2  0x0000000001066601 in runtime.goexit
   at /usr/local/Cellar/go/1.17.2/libexec/src/runtime/asm_amd64.s:1581
(dlv) cc
```

**go 运行时结束退出**

```
> runtime.main() /usr/local/Cellar/go/1.17.2/libexec/src/runtime/proc.go:264 (PC: 0x1038433)
Warning: debugging optimized function
Values returned:

   259:
   260:		// Make racy client program work: if panicking on
   261:		// another goroutine at the same time as main returns,
   262:		// let the other goroutine finish printing the panic trace.
   263:		// Once it does, it will exit. See issues 3934 and 20018.
=> 264:		if atomic.Load(&runningPanicDefers) != 0 {
   265:			// Running deferred functions should not take long.
   266:			for c := 0; c < 1000; c++ {
   267:				if atomic.Load(&runningPanicDefers) == 0 {
   268:					break
   269:				}
(dlv) bt
0  0x0000000001038433 in runtime.main
   at /usr/local/Cellar/go/1.17.2/libexec/src/runtime/proc.go:264
1  0x0000000001066601 in runtime.goexit
   at /usr/local/Cellar/go/1.17.2/libexec/src/runtime/asm_amd64.s:1581
(dlv)
```

**go 进程结束退出**

```bash
> runtime.main() /usr/local/Cellar/go/1.17.2/libexec/src/runtime/proc.go:277 (PC: 0x103847d)
Warning: debugging optimized function
   272:		}
   273:		if atomic.Load(&panicking) != 0 {
   274:			gopark(nil, nil, waitReasonPanicWait, traceEvGoStop, 1)
   275:		}
   276:
=> 277:		exit(0)
   278:		for {
   279:			var x *int32
   280:			*x = 0
   281:		}
   282:	}
(dlv) bt
0  0x000000000103847d in runtime.main
   at /usr/local/Cellar/go/1.17.2/libexec/src/runtime/proc.go:277
1  0x0000000001066601 in runtime.goexit
   at /usr/local/Cellar/go/1.17.2/libexec/src/runtime/asm_amd64.s:1581
```
