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
命令:ldd file 查询文件链接情况
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
`project(<projectname> [languageName1 languageName2 ... ] )`
给工程赋予一个名字


### SET
`set(<variable> <value>
      [[CACHE <type> <docstring> [FORCE]] | PARENT_SCOPE])`

举例:
`SET(SRC_LIST main.c t1.c t2.c)``
### MESSAGE
`message([STATUS|WARNING|AUTHOR_WARNING|FATAL_ERROR|SEND_ERROR]
          "message to display" ...)`

STATUS:打印信息不影响整个流程
SEND_ERROR:产生错误，生成过程被跳过
FATAL_ERROR:立即终止所有camke
WARNING:CMAKE警告，继续处理
AUTHOR_WARNING：开发者警告，继续处理



### ADD_EXECUTABLE
`add_executable(<name> [WIN32] [MACOSX_BUNDLE]
                 [EXCLUDE_FROM_ALL]
                 source1 source2 ... sourceN)``

使用指定的源文件生成一个可执行的文件。

### ADD_SUBDIRECTORY
`add_subdirectory(source_dir [binary_dir]
                   [EXCLUDE_FROM_ALL])`

向构建目录存放一个子目录,(source_dir是源文件需要对应一个单独的CMakeLists.txt文件)

### SET

`set(<variable> <value>
      [[CACHE <type> <docstring> [FORCE]] | PARENT_SCOPE])`

通过value指定源文件给所在位置赋值给所在variable，后面可以通过variable变量名称加载源文件。

### INSTALL
把静态库和动态库存放到指定目录位置
##### TARGETS
```
install(TARGETS targets... [EXPORT <export-name>]
      [[ARCHIVE|LIBRARY|RUNTIME|FRAMEWORK|BUNDLE|   
      PRIVATE_HEADER|PUBLIC_HEADER|RESOURCE]
      DESTINATION <dir>]
      [INCLUDES DESTINATION [<dir> ...]]
      [PERMISSIONS permissions...]
      [CONFIGURATIONS [Debug|Release|...]]
      [COMPONENT <component>]
      [OPTIONAL] [NAMELINK_ONLY|NAMELINK_SKIP]
      ] [...])
```

举例
```
install(TARGETS myExe mySharedLib myStaticLib
        RUNTIME DESTINATION bin
        LIBRARY DESTINATION lib
        ARCHIVE DESTINATION lib/static)
```

`install(TARGETS mySharedLib DESTINATION /some/full/path)`

#### FILES
把文件类型放到指定目录
```
install(FILES files... DESTINATION <dir>
        [PERMISSIONS permissions...]
        CONFIGURATIONS [Debug|Release|...]]
        COMPONENT <component>]
        RENAME <name>] [OPTIONAL])
```
#### PROGRAMS
把shell脚本放到指定目录
```  
install(PROGRAMS files... DESTINATION <dir>
        [PERMISSIONS permissions...]
        [CONFIGURATIONS [Debug|Release|...]]
        [COMPONENT <component>]
        RENAME <name>] [OPTIONAL])
```
#### DIRECTORY
把目录下的文件存放在指定位置
```
install(DIRECTORY dirs... DESTINATION <dir>
        [FILE_PERMISSIONS permissions...]
        [DIRECTORY_PERMISSIONS permissions...]
        [USE_SOURCE_PERMISSIONS] [OPTIONAL]
        [CONFIGURATIONS [Debug|Release|...]]
        [COMPONENT <component>] [FILES_MATCHING]
        [[PATTERN <pattern> | REGEX <regex>]
         [EXCLUDE] [PERMISSIONS permissions...]] [...])
```
##### ARCHIVE|LIBRARY|RUNTIME|DESTINATION｜ERMISSIONS
ARCHIVE：静态库  
LIBRARY:动态库  
RUNTIME：二进制文件  
DESTINATION:存放路径 *以/结尾安装到相对路径  
ERMISSIONS：存放文件权限,安装后的权限为：OWNER_WRITE, OWNER_READ, GROUP_READ,和 WORLD_READ，即 644 权限.    
### ADD_TEST
`add_test(testname Exename arg1 arg2 ... )`
```
ADD_TEST(mytest ${PROJECT_BINARY_DIR}/bin/main)
ENABLE_TESTING()
```
生成 Makefile 后，就可以运行 make test 来执行测试了。

### add_library
```
add_library(<name> [STATIC | SHARED | MODULE]
              [EXCLUDE_FROM_ALL]
              source1 source2 ... sourceN)
```
通过配置的源文件生成一个动态库/静态库。  
STATIC:生成静态库  
SHARED:动态库  
MODULE，在使用 dyld 的系统有效，如果不支持 dyld，则被当作 SHARED 对待。

### SET_TARGET_PROPERTIES
```
set_target_properties(target1 target2 ...
                      PROPERTIES prop1 value1
                      prop2 value2 ...)
```

这条指令可以用来设置输出的名称，对于动态库，还可以用来指定动态库版本和 API 版本。
`SET_TARGET_PROPERTIES(hello_static PROPERTIES OUTPUT_NAME "hello")`  
这条指令是修改hello_static名称为hello
### GET_TARGET_PROPERTIES
查询通过SET_TARGET_PROPERTIES命令修改值的返回结果。  
`MESSAGE(STATUS “This is the hello_static OUTPUT_NAME:”${OUTPUT_VALUE})`  
如果没有这个属性定义，则返回 NOTFOUND.
### INCLUDE_DIRECTORIES
`include_directories([AFTER|BEFORE] [SYSTEM] dir1 dir2 ...)`  
引入头文件

### TARGET_LINK_LIBRARIES
```
target_link_libraries(<target> [item1 [item2 [...]]]
                      [[debug|optimized|general] <item>] ...)
```
这个指令可以用来为 target 添加需要链接的共享库
### FIND_PATH
`find_file(<VAR> name1 [path1 path2 ...])`  
处理一下需要逻辑的场景，先通过FIND_PATH看是否能找到对应文件，配合IF()ENDIF()条件命令，如果FIND_PATH找到对应文件的情况,进行找到文件的处理如果找不到用弥补方式处理
### AUX_SOURCE_DIRECTORY
`AUX_SOURCE_DIRECTORY(dir VARIABLE)``
作用是发现一个目录下所有的源代码文件并将列表存储在一个变量中，这个指令临时被用来
自动构建源文件列表。因为目前 cmake 还不能自动发现新添加的源文件。

### CMAKE_MINIMUM_REQUIRED
`CMAKE_MINIMUM_REQUIRED(VERSION versionNumber [FATAL_ERROR])`
指定一个最低版本号
### EXEC_PROGRAM
```
EXEC_PROGRAM(Executable [directory in which to run]
            [ARGS <arguments to executable>]
            [OUTPUT_VARIABLE <var>]
            [RETURN_VALUE <var>])
```
用于在指定的目录运行某个程序，通过 ARGS 添加参数，如果要获取输出和返回值，可通过
OUTPUT_VARIABLE 和 RETURN_VALUE 分别定义两个变量.  
举例  
```
EXEC_PROGRAM(ls ARGS "*.c" OUTPUT_VARIABLE LS_OUTPUT RETURN_VALUE
LS_RVALUE)
MESSAGE(STATUS "ls result: " ${LS_OUTPUT})
```
打印ls信息
### FILE 文件操作
```
FILE(WRITE filename "message to write"... )  
 FILE(APPEND filename "message to write"... )
 FILE(READ filename variable)
 FILE(GLOB variable [RELATIVE path] [globbing
expressions]...)
 FILE(GLOB_RECURSE variable [RELATIVE path]
 [globbing expressions]...)
 FILE(REMOVE [directory]...)
 FILE(REMOVE_RECURSE [directory]...)
 FILE(MAKE_DIRECTORY [directory]...)
 FILE(RELATIVE_PATH variable directory file)
 FILE(TO_CMAKE_PATH path result)
 FILE(TO_NATIVE_PATH path result)
 ```
 ### INCLUDE
```
 include(<file|module> [OPTIONAL] [RESULT_VARIABLE <VAR>]
                         [NO_POLICY_SCOPE])
```
 你可以指定载入一个文件，如果定义的是一个模块，那么将在 CMAKE_MODULE_PATH 中搜
 索这个模块并载入。  
 OPTIONAL：参数的作用是文件不存在也不会产生错误。

### FIND
FIND_系列指令主要包含一下指令：
1. FIND_FILE(<VAR> name1 path1 path2 ...)
VAR 变量代表找到的文件全路径，包含文件名
2. FIND_LIBRARY(<VAR> name1 path1 path2 ...)
VAR 变量表示找到的库全路径，包含库文件名
3. FIND_PATH(<VAR> name1 path1 path2 ...)
VAR 变量代表包含这个文件的路径。
4. FIND_PROGRAM(<VAR> name1 path1 path2 ...)
VAR 变量代表包含这个程序的全路径。
5. FIND_PACKAGE(<name> [major.minor] [QUIET] [NO_MODULE]
  [[REQUIRED|COMPONENTS] [componets...]])

用来调用预定义在 CMAKE_MODULE_PATH 下的 Find<name>.cmake 模块，你也可以自己定义 Find<name>模块，通过 SET(CMAKE_MODULE_PATH dir)将其放入工程的某个目录中供工程使用，

## 控制指令
### IF
```
if(expression)
  # then section.
  COMMAND1(ARGS ...)
  COMMAND2(ARGS ...)
  ...
elseif(expression2)
  # elseif section.
  COMMAND1(ARGS ...)
  COMMAND2(ARGS ...)
  ...
else(expression)
  # else section.
  COMMAND1(ARGS ...)
  COMMAND2(ARGS ...)
  ...
endif(expression)
```
### 表达式的使用方法如下:
```
IF(var)，如果变量不是：空，0，N, NO, OFF, FALSE, NOTFOUND 或
<var>_NOTFOUND 时，表达式为真。
IF(NOT var )，与上述条件相反。
IF(var1 AND var2)，当两个变量都为真是为真。
IF(var1 OR var2)，当两个变量其中一个为真时为真。
IF(COMMAND cmd)，当给定的 cmd 确实是命令并可以调用是为真。
IF(EXISTS dir)或者 IF(EXISTS file)，当目录名或者文件名存在时为真。
IF(file1 IS_NEWER_THAN file2)，当 file1 比 file2 新，或者 file1/file2 其
中有一个不存在时为真，文件名请使用完整路径。
IF(IS_DIRECTORY dirname)，当 dirname 是目录时，为真。
IF(variable MATCHES regex)
IF(string MATCHES regex)
当给定的变量或者字符串能够匹配正则表达式 regex 时为真。比如：
IF("hello" MATCHES "ell")
MESSAGE("true")
ENDIF("hello" MATCHES "ell")
IF(variable LESS number)
IF(string LESS number)
IF(variable GREATER number)
IF(string GREATER number)
IF(variable EQUAL number)
IF(string EQUAL number)
数字比较表达式
IF(variable STRLESS string)
IF(string STRLESS string)
IF(variable STRGREATER string)
IF(string STRGREATER string)
IF(variable STREQUAL string)
IF(string STREQUAL string)
按照字母序的排列进行比较.
IF(DEFINED variable)，如果变量被定义，为真。
```
### WHILE
WHILE 指令的语法是：
```
 WHILE(condition)
 COMMAND1(ARGS ...)
 COMMAND2(ARGS ...)
 ...
 ENDWHILE(condition)
 ```

其真假判断条件可以参考 IF 指令。

### FOREACH
`FOREACH(loop_var RANGE total)`
`ENDFOREACH(loop_var)`
从 0 到 total 以１为步进

## 常用隐式变量
+ PROJECT_SOURCE_DIR/PROJECT_SOURCE_DIR 当前CMAKELISTS目录
+ CMAKE_CURRENT_LIST_FILE 输出调用这个变量的 CMakeLists.txt 的完整路径
+ CMAKE_CURRENT_LIST_LINE 输出这个变量所在的行
+ PROJECT_NAME 项目范明
+ CMAKE_MAJOR_VERSION，CMAKE 主版本号，比如 2.4.6 中的 2
+ CMAKE_MINOR_VERSION，CMAKE 次版本号，比如 2.4.6 中的 4
+ CMAKE_PATCH_VERSION，CMAKE 补丁等级，比如 2.4.6 中的 6
+ CMAKE_SYSTEM，系统名称，比如 Linux-2.6.22
+ CMAKE_SYSTEM_NAME，不包含版本的系统名，比如 Linux
+ CMAKE_SYSTEM_VERSION，系统版本，比如 2.6.22
+ CMAKE_SYSTEM_PROCESSOR，处理器名称，比如 i686.
+ UNIX，在所有的类 UNIX 平台为 TRUE，包括 OS X 和 cygwin
+ WIN32，在所有的 win32 平台为 TRUE，包括 cygwin
+ BUILD_SHARED_LIBS 这个开关用来控制默认的库编译方式，如果不进行设置，使用 ADD_LIBRARY 并没有指定库类型的情况下，默认编译生成的库都是静态库。如果 SET(BUILD_SHARED_LIBS ON)后，默认生成的为动态库。
+ CMAKE_C_FLAGS 设置 C 编译选项，也可以通过指令 ADD_DEFINITIONS()添加
+ CMAKE_CXX_FLAGS 设置 C++编译选项，也可以通过指令 ADD_DEFINITIONS()添加。
## cmake 调用环境变量的方式
使用$ENV{NAME}指令就可以调用系统的环境变量了。
例子
`MESSAGE(STATUS “HOME dir: $ENV{HOME}”)`
设置环境变量的方式是：  
SET(ENV{变量名} 值)
