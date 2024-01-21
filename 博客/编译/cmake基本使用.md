# Cmake总结

## Cmake概念
Cmake工程编译工具，CMake开发始在1999年，2001年由kitware公司开源的工程编译工具，Cmake是跨平台免费的开源软件，常用编译C/C++/文件生成对应的静态库和动态库。

## Camke安装
官方网站:www.cmake.org </br>
mac平台安装:brew install camke。
## Cmake执行流程
创建CMakeLists.txt文件
编写CMakeLists.txt文件
Cmake .(.代表当前目录)命令执行CmakeLists.txt文件生成对应MakeFile文件
make执行MakeFile文件，生成对应动态库和静态库

## make构建的详细过程
命令:make VERBOSE=1
命令:make clean 清理构建结果文件
## Cmake平台特点
+ 仅依赖于系统 C++ 编译器，意味着没有第三方库
+ 能够生成 Visual Studio IDE 输入文件
+ 能够生成可执行和可链接的二进制库（静态和共享）
+ 能够运行构建时代码生成器
+ 单独的源/构建文件树
+ 系统检查和内省（类似于Autotools）：系统可以做什么和不能做什么
+ 自动扫描C/C++依赖
+ 跨平台


## Cmake语法介绍
Cmake命令语法大小写都可以兼容但是推荐命令大写。

### PROJECT
project(<projectname> [languageName1 languageName2 ... ] )</br>
给工程赋予一个名字


### SET
set(<variable> <value>
      [[CACHE <type> <docstring> [FORCE]] | PARENT_SCOPE])

举例:
SET(SRC_LIST main.c t1.c t2.c)
### MESSAGE
message([STATUS|WARNING|AUTHOR_WARNING|FATAL_ERROR|SEND_ERROR]
          "message to display" ...)

STATUS:打印信息不影响整个流程
SEND_ERROR:产生错误，生成过程被跳过
FATAL_ERROR:立即终止所有camke
WARNING:CMAKE警告，继续处理
AUTHOR_WARNING：开发者警告，继续处理



### ADD_EXECUTABLE
add_executable(<name> [WIN32] [MACOSX_BUNDLE]
                 [EXCLUDE_FROM_ALL]
                 source1 source2 ... sourceN)

使用指定的源文件生成一个可执行的文件。

### ADD_SUBDIRECTORY
add_subdirectory(source_dir [binary_dir] 
                   [EXCLUDE_FROM_ALL])

向构建目录存放一个子目录,(source_dir是源文件需要对应一个单独的CMakeLists.txt文件)

### SET
set(<variable> <value>
      [[CACHE <type> <docstring> [FORCE]] | PARENT_SCOPE])

通过value指定源文件给所在位置赋值给所在variable，后面可以通过variable变量名称加载源文件。

### install

install(TARGETS targets... [EXPORT <export-name>]
          [[ARCHIVE|LIBRARY|RUNTIME|FRAMEWORK|BUNDLE|
            PRIVATE_HEADER|PUBLIC_HEADER|RESOURCE]
           [DESTINATION <dir>]
           [INCLUDES DESTINATION [<dir> ...]]
           [PERMISSIONS permissions...]
           [CONFIGURATIONS [Debug|Release|...]]
           [COMPONENT <component>]
           [OPTIONAL] [NAMELINK_ONLY|NAMELINK_SKIP]
          ] [...])

