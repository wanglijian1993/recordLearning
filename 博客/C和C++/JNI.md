

# JNI

## SO

NDK编译在linux下能执行的函数库-so文件，其本质就是一堆C，C++的头文件和现实文件打包成一个库

## JNI

上层Java通过JNi来调用NDK层(C/C++)

## window平台

静态库:lib静态连结库

动态库::dll 动态连结库



## linux平台

动态连接库:.so

静态连接库.a

## Cmakelist.txt配置编译动态库和静态库

引入一些so文件

SHARED共享，动态，STATIC 静态



## 静态注册

步骤:

1. 编写java类，加入是JniText.java
2. 在命令行下输入javac jniTest.java 生成JniTest.class文件
3. 在JniTest.class目录下 通过javah xxx.JniTest(全类名)生成 xxx_JniTest.h
4. 编写xxx_JniTest.c源文件，并拷贝xxx_JniTest.h下的函数，并实现这些函数，并在其中添加jni.h文件
5. 编写cmakelist.txt文件，编译生成动态/静态链接库



## JNI上下文

### JniEnv*(结构体)

实际代表了Java环境，通过这个JniEnv*指针，就可以对Java段的代码进行操作。 例如，创建Java类中的对象，调用Java对象的方法，获取Java对象中的属性等等。JNIEnv的指针会被JNI传入到本地方法的实现函数中来对Java端的代码进行操作。

## Jobject*

  1)如果native方法不是static的话，**这个obj就代表这个native方法的类实例。

2）如果native方法是static的话，*这个obj就代表这个native方法的类的class对象实例() *(static方法不需要类的实例的，所以就代表这个类的class对象)





