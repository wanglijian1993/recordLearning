# Android跨进程通信

## Android多进程模式

创建线程的方式

```
//方式一
<activity android:name=".process.SecondActivity"
    android:process=":remote"/>
    
```

```
方式二
<activity android:name=".process.SecondActivity"
    android:process="com.android.ipc:03"/>
```

区别



多进程的问题

- 静态成员和单例模式失效
- 线程同步机制失效
- Application会多次创建





## Serializable和Parcelable



## Binder机制





Mmap