# C++

## 头文件命名约定

| 头文件类型  | 约定                 | 示例       | 说明                                                   |
| ----------- | -------------------- | ---------- | ------------------------------------------------------ |
| C++旧式风格 | 以.h结尾             | iostream.h | C++程序可以使用                                        |
| C旧式风格   | 以.h结尾             | math.h     | c,c++程序可以使用                                      |
| C++新式风格 | 没有扩展名           | iostream   | C++程序可以使用，使用namespace std                     |
| 转换后的C   | 加上前缀c,没有扩展名 | cmath      | C++程序可以使用，可以使用不是C的特性，如 namespace std |

## C++基础数据类型

**11中整形3中浮点类型**

### 整形

short:至少16位

int至少与short一样长

long至少32位，且至少与int一样长

long long 至少64位，且至少与long一样长

### 浮点类型

float至少32位

dobule 至少48位

long dobule



boolean类型



### 无符号整型

无符号整型可以整大变量狗能存储最大的值。

unsigned short

unsigned int 

unsigned long

unsigned long long 



**ioStream**:涉及程序与外部世界之间的通信。iosstream中的io指的是输入(进入程序的信息)和输出(从程序中发送出去的信息)。

**using namespace std**:提供一个命名空间省略后面代码 示例:命名空间::函数//std::cout

**函数调用示例**

打印输出:std::cout << string 命名空间::对象 插入运算符 字符串

**<<:** C++操作运算符重载表示把string的流给运算符前面的对象里

**endl:**控制符重起一行

**cin:** cin::变量名 可以通过键盘输入的值到变量里

**#define** 名称 替换数字

**const：**定义常量

**auto:**类型判断