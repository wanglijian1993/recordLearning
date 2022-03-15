# C语言基础一

## 字长

- 字长是CPU主要技术指标之一，指的是CPU一次最大能并行处理的二进制位数。
- 现在主要流行的计算机字长是32位和64位

## 原码，反码，补码

- 为了表示负数，将最高位解释为符号位
- 正数的原码，反码，补码均相同
- 对于负数，已知原码求反码，符号位不变，其他位按位求反
- 对于负数，已知原码求补码，先求反码，再反码位末尾+1

## 数据类型

### 类型

- 字符

- 整形
- 浮点型

#### 常量定义

1. 使用#define预处理起

   #define indentifier value

2. 使用const关键字

   const type variable=value

#### C存储类

auto是局部变量的存储类，限定变量只能在函数内部使用

register代表了寄存器变量，不在内存中使用

static是全局变量的默认存储类，表示变量在程序生命周期可见

extern表示全局变量，即对程序内所有文件可见，类似于Java中的public关键字

#### C导入文件

#include   系统文件:#<>  #"自己编写的文件“

#### C预处理器

#define 定义宏

#include 包含一个源代码文件

#undef 取消已定义的宏

#ifdef 如果宏已经定义，则返回真

#ifndef 如果宏没有定义，则返回真

#if 如果给定条件为真,则编译下面的代码

#else #if替代方案

#endif  结束一个#if...#else条件编译块

#error 当遇到标准错误时，输出错误消息

#pragma 使用标准化方法，向编译器发布特殊的命令到编译器中

#### 预处理运算符

C预处理提供了下列的运算符来帮助你建宏

**宏延续运算符(\)**

   一个宏通常写在一个单行上，但是如果宏太长，一个单行容纳不下，则使用延续运算符(\)

   例如:#define message_for(a,b) \ 

 				prontf(#a "and  #b":we love you !\n)

 **字符串运算符**（#）

​			在宏定义中，当需要把一个宏的参数转换为字符串常量时，则使用字符串常量运算符(#).在宏中使用该运算符有一个特定的参数或参数列表.例如

​			#include <studi.o>

​			#define message_for(a,b) \

​				printf(#a "and "#b":we love you!\n)

当上面的代码被编译和执行时，它会产生下列结果:

​		int main(void)

​		{

​			message_for(Carole,Debra)

​			打印:Carole and Debra:We love you

 		}

 **标记粘贴运算符(##)**

 宏定义内的标记粘贴运算符(##)会合并两个参数，它允许在宏定义中两个独立的标记被合为一个标记，例如

​		#include <studio.h>

​		#define tokenpaster(n) printf("token "#n"=%d",token##n)

​     int main(void){

​		int token34=40;

​		tokenpaster(34);

​		return o;		

​	}			

   token34=40

### 构造类型

- 数组
- 结构体(struct)
- 共同体(union)
- 枚举(enum)

### 指针

### Void

## Type vs #define

#define是C指令，用于为各种类型定义别名，与typedef类似，但是它们有以下几点不同:

#typedef 仅限于类型定义符号名称，#define不仅可以为类型定义别名，也能为数字定义别名,比如你可以定义1为One。

typedef是由编译器执行解释的,#define语句是有编译器进行处理的

## 格式化打印数据

%a       浮点数、十六进制数字和p-记数法（Ｃ９９）
%A　　　　浮点数、十六进制数字和p-记法（Ｃ９９）
%c　　　　 一个字符(char)

%C      一个ISO宽字符

%d　　　　有符号十进制整数(int)（%e浮点数、e-记数法
%E　　　　浮点数、Ｅ-记数法
%f　　　　 单精度浮点数(默认float)、十进制记数法（%.nf  这里n表示精确到小数位后n位.十进制计数）

%g　　　　根据数值不同自动选择％f或％e．
%G　　　　根据数值不同自动选择％f或％e.
%i       有符号十进制数（与％d相同）
%o　　　　无符号八进制整数
%p　　　  指针
%s　　　　 对应字符串char*（%S       对应宽字符串WCAHR*（%u　　　  无符号十进制整数(unsigned int)
 %x　　　　使用十六进制数字０f的无符号十六进制整数　
 %X　　　  使用十六进制数字０f的无符号十六进制整数
 %%　　　 打印一个百分号

## 指针

### 符号

- &运算符，用于取一个对象的地址
- *是一个间接寻址符，用于访问指针所指向的地址的值

​	1.int *ptr(定义一个指针) 2.int b=*ptr用于访问指针所指向的地址的值

-  &与* 是一对互逆的运算

**malloc,realloc,free**

```
//最初内存分配
prt_i=(int *)malloc(sizeof(int));

    //重新分配内存
prt_i= (int*)realloc(prt_i,sizeof(int)*50);
    
  //悬空指针
    free(prt_i);
    prt_i=NULL;    
```

 