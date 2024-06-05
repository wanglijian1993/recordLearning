# ArkTS基础数据类型

## number类型
基础的数字类型，包含整数和浮点数。
整数字面量包括以下类别:
<ul>
<li>由数字序列组成的十进制整数。例如：0、117、-345</li>
<li>以0x（或0X）开头的十六进制整数，可以包含数字（0-9）和字母a-f或A-F。例如：0x1123、0x00111、-0xF1A7</li>
<li>以0o（或0O）开头的八进制整数，只能包含数字（0-7）。例如：0o777</li>
<li>以0b（或0B）开头的二进制整数，只能包含数字0和1。例如：0b11、0b0011、-0b11</li>
</ul>
浮点字面量包括以下：
<ul>
<li>十进制整数，可为有符号数（即，前缀为“+”或“-”）；</li>
<li>小数点（“.”）</li>
<li>小数部分（由十进制数字字符串表示）</li>
<li>以“e”或“E”开头的指数部分，后跟有符号（即，前缀为“+”或“-”）或无符号整数。</li>
</ul>

## boolean类型
boolean类型由true和false两个逻辑值组成

## string类型
string代表字符序列
字符串可以被单引号，双引号，反向单引号括起来的摸板字面量。

<code>
let s1:string='hello world'; //单引号<br>
let s2:string="hello world"; //双引号<br>
let world:string='world';<br>
let s3:string=`hello ${world}`;//反向字面量<br>
</code>

## void类型
void类型用于接受函数没有返回值。

`
class MyCls<T>{
}
let instance:MyCls<void> =new MyCls<void>();
instance.toAdd();
`

## object类型
object类型是所有引用类型的基类型。任何值，包括基本类型的值(它们会被自动装箱)，都可以直接被赋给Object类型的变量。

## Array类型
array，即数组，同一类型的数据集合体。
`let names: string[] = ['Alice', 'Bob', 'Carol'];`

## Enum类型
enum类型，又称枚举类型，是预先定义的一组命名值的值类型。
使用枚举常量时必须以枚举类型名称为前缀
`enum ColorSet { Red, Green, Blue }
let c: ColorSet = ColorSet.Red;`

常量表达式可以用于显式设置枚举常量的值
`enum ColorSet { White = 0xFF, Grey = 0x7F, Black = 0x00 }
let c: ColorSet = ColorSet.Black;`

## Union类型
union类型，即联合类型，是由多个类型组合成的引用类型。
`let union:number|string; `
