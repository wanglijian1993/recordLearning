# C/C++语法篇

## 基本内置数据类型

C++ 为程序员提供了种类丰富的内置数据类型和用户自定义的数据类型。下表列出了七种基本的 C++ 数据类型：

| 类型     | 关键字  |
| :------- | :------ |
| 布尔型   | bool    |
| 字符型   | char    |
| 整型     | int     |
| 浮点型   | float   |
| 双浮点型 | double  |
| 无类型   | void    |
| 宽字符型 | wchar_t |

常用基本数据类型占用空间（64位机器为例）

-  char ： 1个字节
-  int ：4个字节
-  float：4个字节
-  double：8个字节

**指针和引用的定义**

int a;  //定义一个int类型的变量

int* a; //代表int类型a的指针

int*b=&a; //&a代表取a的地址赋值给int* a

int** a;//二级指针对地址再取地址

**数组的定义**

int[] arr={1,2,3,4};

int* arr_p=&arr; //arr_p指针是数组的首位地址的指针

指针的移动可以进行 i++,i+=2操作，注意数组下标越界



**举例：a，b值交换**

```
void change(int* a,int* b) {
	int temp = *a;
	*a = *b;
	*b = temp;
}
int a = 100;
int b = 200;
change(&a, &b);
```

**举例数组的遍历赋值操作**

```
int[] arr={1,2,3,4}
int* arr_p=&arr;
int i=0;
//遍历
for(;i<4;i++){
 printf("遍历i:%d",*(arr+i))//方式一
 printf("遍历i:%d",*(arr_p+i))//方式二
 printf("遍历i:%d",arr[i])//方式三
}
//赋值
int j=0;
for (; i < 4; i++) {
	*(arr + i) = 1;
}

```

## 二内存的操作

malloc 动态开辟内存

free 释放内存