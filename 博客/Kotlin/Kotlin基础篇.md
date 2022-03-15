# Kotlin基础篇

## 基本类型

Kotlin中四种基本类型:数字、字符、布尔值、数组与字符串

![image-20210802142211112](C:\Users\wanglj\AppData\Roaming\Typora\typora-user-images\image-20210802142211112.png)

### Kotlin类型推导

val one = 1 // Int
val threeBillion = 3000000000 // Long
val oneLong = 1L // Long
val oneByte: Byte = 1

所有以未超出 `Int` 最大值的整型值初始化的变量都会推断为 `Int` 类型。如果初始值超过了其最大值，那么推断为 `Long` 类型。 如需显式指定 `Long` 型值，请在该值后追加 `L` 后缀。

对于浮点数，Kotlin 提供了 `Float` 与 `Double` 类型。 根据 [IEEE 754 标准](https://zh.wikipedia.org/wiki/IEEE_754)， 两种浮点类型的*十进制位数*（即可以存储多少位十进制数）不同。 `Float` 反映了 IEEE 754 *单精度*，而 `Double` 提供了*双精度*。

![image-20210802143004219](C:\Users\wanglj\AppData\Roaming\Typora\typora-user-images\image-20210802143004219.png)

对于以小数初始化的变量，编译器会推断为 `Double` 类型。 如需将一个值显式指定为 `Float` 类型，请添加 `f` 或 `F` 后缀。 如果这样的值包含多于 6～7 位十进制数，那么会将其舍入。

![image-20210802143136906](C:\Users\wanglj\AppData\Roaming\Typora\typora-user-images\image-20210802143136906.png)

##  装箱拆箱

装箱:基本类型转换成包装类型

在装箱的时候自动调用的是Object的valueOf(object)方法

拆箱:包装类型转换成基本类型

在拆箱的时候自动调用的是Object的ObjValue方法

### ==，===符号

==：结构相等由 `==`（以及其否定形式 `!=`）操作判断。按照惯例，像 `a == b` 这样的表达式会翻译成：a?.equals(b) ?: (b === null)

===：引用相等由 `===`（以及其否定形式 `!==`）操作判断。`a === b` 当且仅当 `a` 与 `b` 指向同一个对象时求值为 true。对于运行时表示为原生类型的值 （例如 `Int`），`===` 相等检测等价于 `==` 检测。



## 函数式(SAM：Single Abstract Method Conversions)接口

只有一个抽象方法的接口称为函数式接口或SAM(单一抽象方法)接口。函数式接口可以有多个非抽象成员，但只能有一个抽象成员。

可以用 `fun` 修饰符在 Kotlin 中声明一个函数式接口

```
fun interface IntPredicate {
   fun accept(i: Int): Boolean
}
```

不使用SAM转换

```
// 创建一个类的实例
val isEven = object : IntPredicate {
   override fun accept(i: Int): Boolean {
       return i % 2 == 0
   }
}
```

通过利用 Kotlin 的 SAM 转换，可以改为以下等效代码：



```
// 通过 lambda 表达式创建一个实例
val isEven = IntPredicate { it % 2 == 0 }
```



## 可见性修饰符

private:意味着只在这个类内部（包含其所有成员）可见

protected:和 `private`一样 + 在子类中可见

internal:能见到类声明的 *本模块内* 的任何客户端都可见其 `internal` 成员

public:能见到类声明的任何客户端都可见其 `public` 成员

## 扩展函数

Kotlin能够扩展一个类的新功能而无需继承该类或者使用像装饰者这样的设计模式。者通过叫做扩展的特俗声明完成。例如，你可以为一个你不能修改的，来自第三方库中的类编写一个新的函数。这个新增的函数就像那个原始类本来就有的函数一样，可以用普通的方法调用。这种机制称为扩展函数。此外，也有扩展属性，允许你为一个已经存在的类添加新的属性。

声明一个扩展函数，我们需要用一个 *接收者类型* 也就是被扩展的类型来作为他的前缀。 下面代码为 `MutableList<Int>` 添加一个`swap` 函数：

```
fun MutableList<Int>.swap(index1: Int, index2: Int) {
    val tmp = this[index1] // “this”对应该列表
    this[index1] = this[index2]
    this[index2] = tmp
}
```

通过JVM编译后

```
public final class BeanKt {
   public static final void swap(@NotNull List $this$swap, int index1, int index2) {
      Intrinsics.checkNotNullParameter($this$swap, "$this$swap");
      int tmp = ((Number)$this$swap.get(index1)).intValue();
      $this$swap.set(index1, $this$swap.get(index2));
      $this$swap.set(index2, tmp);
   }
}
```

扩展函数并不能真正的修改他们所扩展的累。通过定义一个扩展，你并没有在一个类中插入新成员，仅仅是通过该类型的变量用点表达式去调用这个新函数。

### 伴生对象的扩展

如果一个类订一有一个伴生对象，你也可以为伴生对象订一扩展函数与属性。就像伴生对象的常规成员一样，可以使用类名作为限定符来调用伴生对象的扩展成员

```
class MyClass {
    companion object { }  // 将被称为 "Companion"
}

fun MyClass.Companion.printCompanion() { println("companion") }

fun main() {
    MyClass.printCompanion()
}
```

JVM编译后

```
public final class MyClass {
   @NotNull
   public static final MyClass.Companion Companion = new MyClass.Companion((DefaultConstructorMarker)null);
   public static final class Companion {
      private Companion() {
      }
      public Companion(DefaultConstructorMarker $constructor_marker) {
         this();
      }
   }
}
```

就是声明的单例模式

## 密封类

要声明一个密封类，需要在类名前面添加`sealed`修饰符。密封类也可以有子类，但是所有子类都必须在与密封类自身相同的文件中声明。

```
sealed class Expr
```

通过JVM转换

```
public abstract class Expr {
   private Expr() {
   }
}
```

其实密闭类的本质就是抽象类

```
data class Const(val number: Double) : Expr()
object NotANumber : Expr()
```

```
public final class Const extends Expr {
   private final double number;

   public final double getNumber() {
      return this.number;
   }

   public Const(double number) {
      super((DefaultConstructorMarker)null);
      this.number = number;
   }

   public final double component1() {
      return this.number;
   }

   @NotNull
   public final Const copy(double number) {
      return new Const(number);
   }

   // $FF: synthetic method
   public static Const copy$default(Const var0, double var1, int var3, Object var4) {
      if ((var3 & 1) != 0) {
         var1 = var0.number;
      }

      return var0.copy(var1);
   }

   @NotNull
   public String toString() {
      return "Const(number=" + this.number + ")";
   }

   public int hashCode() {
      long var10000 = Double.doubleToLongBits(this.number);
      return (int)(var10000 ^ var10000 >>> 32);
   }

   public boolean equals(@Nullable Object var1) {
      if (this != var1) {
         if (var1 instanceof Const) {
            Const var2 = (Const)var1;
            if (Double.compare(this.number, var2.number) == 0) {
               return true;
            }
         }

         return false;
      } else {
         return true;
      }
   }
}

public final class NotANumber extends Expr {
   @NotNull
   public static final NotANumber INSTANCE;

   private NotANumber() {
      super((DefaultConstructorMarker)null);
   }

   static {
      NotANumber var0 = new NotANumber();
      INSTANCE = var0;
   }
}
```

- 一个密封类是自身[抽象的](http://www.kotlincn.net/docs/reference/classes.html#抽象类)，它不能直接实例化并可以有抽象（*abstract*）成员。
- 密封类不允许有非-*private* 构造函数（其构造函数默认为 *private*）。
- 请注意，扩展密封类子类的类（间接继承者）可以放在任何位置，而无需在同一个文件中。

```
fun eval(expr: Expr): Double = when(expr) {
    is Const -> expr.number
    is Sum -> eval(expr.e1) + eval(expr.e2)
    NotANumber -> Double.NaN
    // 不再需要 `else` 子句，因为我们已经覆盖了所有的情况
}
```

使用密封类的关键好处在于使用 [`when` 表达式](http://www.kotlincn.net/docs/reference/control-flow.html#when-表达式) 的时候，如果能够验证语句覆盖了所有情况，就不需要为该语句再添加一个 `else` 子句了。当然，这只有当你用 `when` 作为表达式（使用结果）而不是作为语句时才有用。



## 泛型

### java泛型

java在1.5之后加入了泛型的概念。泛型，即"**参数化类型**"。泛型的本质就是为了参数化类型(将类型参数化传递)(在不创建新的类型的情况下，通过泛型指定的不通类型来控制形参具体限制的类型)。也就是说在泛型使用的过程中，**操作的数据类型被指定为一个参数**，这种阐述类型可以用在类，接口和方法中，分别被称为**泛型类，泛型接口，泛型方法。**

**java泛型擦除**：java在编译之后采取了**去泛型化**的措施，也就是泛型的类型擦除，java中的泛型只在编译阶段有效。在编译过程中，**正确的校验泛型结果后**，会将泛型的相关信息擦除，并且在对象进入和离开方法的边界处添加类型检查和类型转换的方法。

**泛型类型在逻辑上看是多个不同的类型，实际上是相同的基本类型。**

**通配符？**：类型通配符一般是使用？代替具体的类型实参，**此处’？’是类型实参，而不是类型形参**，可以把？看成所有类型的父类。是一种真实的类型，可以解决当具体类型不确定的时候，这个通配符就是**?**;当操作类型时，不许元使用类型的具体功能时，只使用object类中的功能，那么可以用？通配符来表示未知类型。

### 泛型上下边界

**上边界：**即传入的类型实参必须是指定类型的子类型

**下边界：**即传入的类型实参必须是指定类型或者是父类

### Kotlin泛型

out  ？ extend Object 

in   ？ super Object

## 类型别名

类型别名为现有类型提供替代名称。如果类型名称太长，你可以另外引入较短的名称，并使用新的名称替代原类型名。

**对象类型**

```
typealias NodeSet = Set<Network.Node>

typealias FileTable<K> = MutableMap<K, MutableList<File>>
```

**函数类型**

```
typealias MyHandler=(Int,String, Any) -> Unit
typealias Predicate<T>= (T) -> Boolean
```

类型别名不会引入新类型。它们等效于相应的底层类型。

## 内联类

内联类必须含有唯一的一个属性在主构造函数中初始化。在运行时，将使用这个唯一属性来表示内联类的实例

```
inline class Name(val s: String) {
    val length: Int
        get() = s.length

    fun greet() {
        println("Hello, $s")
    }

}    

fun main() {
    val name = Name("Kotlin")
    name.greet() // `greet` 方法会作为一个静态方法被调用
    println(name.length) // 属性的 get 方法会作为一个静态方法被调用
    }
```

内联类注意

- 内联类不能含有init代码块
- 内联类不能含有幕后字段(通field符号进行set赋值)
- 内联类只能含有简单的计算属性(不能含有延迟初始化/委托属性)

## 委托

### 委托对象

委托模式已经整明是实现继承的一个很好的替代方式，而Kotlin可以零样坂代码地原生支持它。

```
interface Base {
    fun print()
}

class BaseImpl(val x: Int) : Base {
    override fun print() { print(x) }
}

class Derived(b: Base) : Base by b

fun main() {
    val b = BaseImpl(10)
    Derived(b).print()
}
```

`Derived`的超类型列表中的by-子句表示`b`将会再`Derived`中内部存储，并且编译器将生成转发给`b`的所有`Base`的方法。

### 委托属性

-延迟属性(lazy properties):其值只在首次访问时计算;

-可观察属性(observable properties):监听器会受到有关此属性变更的通知;

-把多个属性存储再一个映射(map)中，而不是每个存在单独的字段中。

#### 延迟属性Lazy

```
val lazyValue: String by lazy {
    println("computed!")
    "Hello"
}

fun main() {
    println(lazyValue)
    println(lazyValue)
}
```

SYNCHRONIZED:该值只在一个线程中计算，并且所有线程会看到相同的值。如果初始化委托的同步锁不是必需的，这样多个线程可以同时执行，

PUBLICATION:多个线程计算值，第一个线程完成的返回值将用作Lazy实例的值。

NONE:它不会有任何线程安全的保证以及相关的开销,如果是同一个引用函数也不会重新创建

### 可观察属性Observable

Delegates.observable()接受二个参数:初始值与修改时处理程序(handler).每当我们属性赋值时会调用该处理程序(在赋值后执行)。它有三个参数:该赋值的属性，旧值与新值。

```
class User {
    var name: String by Delegates.observable("<no name>") {
        prop, old, new ->
        println("$old -> $new")
    }
}

fun main() {
    val user = User()
    user.name = "first"
    user.name = "second"
}
<no name> -> first
first -> second

```

### 委托给另一个属性

从Kotlin1.4开始，一个属性可以把它的getter与setter委托给另一个属性。这种委托对于顶层和类的属性(成员和扩展)都可用。该委托属性可以为:

- 顶层属性

- 同一个类的成员或扩展属性

- 另一个类的成员或扩展属性

  为将一个属性委托给另一个属性，应在委托名称中使用恰当的 `::` 限定符，例如，`this::delegate` 或 `MyClass::delegate`

  ```
  class MyClass(var memberInt: Int, val anotherClassInstance: ClassWithDelegate) {
      var delegatedToMember: Int by this::memberInt
      var delegatedToTopLevel: Int by ::topLevelInt
      
  
      val delegatedToAnotherClass: Int by anotherClassInstance::anotherClassInt
  
  }
  var MyClass.extDelegated: Int by ::topLevelInt
  ```

  这是很有用的，例如，当想要以一种向后兼容的方式重命名一个属性的时候：引入一个新的属性、 使用 `@Deprecated` 注解来注解旧的属性、并委托其实现。

  ```
  class MyClass {
     var newName: Int = 0
     @Deprecated("Use 'newName' instead", ReplaceWith("newName"))
     var oldName: Int by this::newName
  }
  
  fun main() {
     val myClass = MyClass()
     // 通知：'oldName: Int' is deprecated.
     // Use 'newName' instead
     myClass.oldName = 42
     println(myClass.newName) // 42
  }
  ```

  #### 将属性存储在映射中

  一个常见的用例实在一个映射(map)里存储属性的值。这经常出现在像解析JSON或者做其他"动态"事情的应用中。在这种情况下，

  ## 高阶函数

  高阶函数是将函数用作参数或返回值的函数

## 集合







