# OpenCv配置

## MVS环境配置

**1.系统环境变量配置**

**path:opencv\opencv\build\x64\vc14\bin**

**2.配置头文件包含目录**

**C:\Users\wanglj\Desktop\opencv\opencv\build\include**

**3.库目录**

**C:\Users\wanglj\Desktop\opencv\opencv\build\x64\vc14\lib**

**4.连接器**

 **链接器：opencv_world340d.lib** 

**5最后还有 dll 系统匹配**



## openCV常用函数

1.imread:读取本地文件转换成Mat对象类型

2.cvtColor:资源色值转换

3.imwrite:往本地写入一个资源

4.imshow:显示资源

5.saturate_cast:opencv会对像素进行加减乘除等一系列操作，操作过程中会低于0或超过255范围，低于0转为0超过255为255

