# Android进程通信

# Binder

Binder是Android中的一个类,它实现了IBinder接口,从IPC角度来说,Binder是Android中的一种跨进程通讯方式,Binder还可以理解为一种虚拟的物理设备,它的设备驱动是/dev/binder,该通讯方式在Linux中没有,从Android framework角度来说,Binder是ServiceManager链接各种Manager(ActivityManager,WindowManager,等等)和相应ManagerService的桥梁,从Android应用层来说,Binder是客户端和服务端进行通信的媒介。

c/s架构

**Descriptor**

Binder的唯一标识,一般用当前Binder的类名表示

**asInterface(android.os.IBinder obj)**

用于将服务端的Binder对象转换成客户端所需的AIDL接口类型的对象,这种转换过程是区分进程的,如果客户端和服务端位于同一个进程,那么此方法返回的就是服务端的Stub对象本身,否则返回的就是系统封装后的Stub.proxy对象。

**onTransact**

这个方法运行在服务端中的Binder线程池中,当客户端发起跨进程请求时,原创请求会通过系统底层封装后交由此方法来处理.该方法原型为

public [boolean](https://cs.android.com/android/platform/superproject/+/master:out/soong/.intermediates/frameworks/base/framework-minus-apex/android_common/xref30/srcjars.xref/android/os/IMessenger.java;drc=master;bpv=1;bpt=1;l=66?gsn=boolean&gs=kythe%3A%3Flang%3Djava%23boolean%23builtin) [onTransact](https://cs.android.com/android/platform/superproject/+/master:out/soong/.intermediates/frameworks/base/framework-minus-apex/android_common/xref30/srcjars.xref/android/os/IMessenger.java;drc=master;bpv=1;bpt=1;l=66?gsn=onTransact&gs=kythe%3A%2F%2Fandroid.googlesource.com%2Fplatform%2Fsuperproject%3Flang%3Djava%3Fpath%3Dandroid.os.IMessenger.Stub%23b3780b814aee081123658acd4e02cf24f16aadd5bb9b4a5c297a0e70a056a991)([int](https://cs.android.com/android/platform/superproject/+/master:out/soong/.intermediates/frameworks/base/framework-minus-apex/android_common/xref30/srcjars.xref/android/os/IMessenger.java;drc=master;bpv=1;bpt=1;l=66?gsn=int&gs=kythe%3A%3Flang%3Djava%23int%23builtin) [code](https://cs.android.com/android/platform/superproject/+/master:out/soong/.intermediates/frameworks/base/framework-minus-apex/android_common/xref30/srcjars.xref/android/os/IMessenger.java;drc=master;bpv=1;bpt=1;l=66?gsn=code&gs=kythe%3A%2F%2Fandroid.googlesource.com%2Fplatform%2Fsuperproject%3Flang%3Djava%3Fpath%3Dandroid.os.IMessenger.Stub%230106be754dc5100dbf8a69db64ce274197d9e8739ac079a4962c44812005231d), [android.os](https://cs.android.com/android/platform/superproject/+/master:out/soong/.intermediates/frameworks/base/framework-minus-apex/android_common/xref30/srcjars.xref/android/os/IMessenger.java;drc=master;bpv=1;bpt=1;l=66?gsn=android.os&gs=kythe%3A%3Flang%3Djava%23140336e1095d5eda443959eca3a6510d203e7dc3c98e2324a53c0d3d692438f5).[Parcel](https://cs.android.com/android/platform/superproject/+/master:frameworks/base/core/java/android/os/Parcel.java;drc=master;bpv=1;bpt=0;l=199) [data](https://cs.android.com/android/platform/superproject/+/master:out/soong/.intermediates/frameworks/base/framework-minus-apex/android_common/xref30/srcjars.xref/android/os/IMessenger.java;drc=master;bpv=1;bpt=1;l=66?gsn=data&gs=kythe%3A%2F%2Fandroid.googlesource.com%2Fplatform%2Fsuperproject%3Flang%3Djava%3Fpath%3Dandroid.os.IMessenger.Stub%234ed1bc8830e70cfb5b417a4716f31263265cef2a2194d596dfb4930887266231), [android.os](https://cs.android.com/android/platform/superproject/+/master:out/soong/.intermediates/frameworks/base/framework-minus-apex/android_common/xref30/srcjars.xref/android/os/IMessenger.java;drc=master;bpv=1;bpt=1;l=66?gsn=android.os&gs=kythe%3A%3Flang%3Djava%23140336e1095d5eda443959eca3a6510d203e7dc3c98e2324a53c0d3d692438f5).[Parcel](https://cs.android.com/android/platform/superproject/+/master:frameworks/base/core/java/android/os/Parcel.java;drc=master;bpv=1;bpt=0;l=199) [reply](https://cs.android.com/android/platform/superproject/+/master:out/soong/.intermediates/frameworks/base/framework-minus-apex/android_common/xref30/srcjars.xref/android/os/IMessenger.java;drc=master;bpv=1;bpt=1;l=66?gsn=reply&gs=kythe%3A%2F%2Fandroid.googlesource.com%2Fplatform%2Fsuperproject%3Flang%3Djava%3Fpath%3Dandroid.os.IMessenger.Stub%23c011e4ae2701a4ae69ad45dc94229c4b7505280d5ba75cbd3c679b3707a915ba), [int](https://cs.android.com/android/platform/superproject/+/master:out/soong/.intermediates/frameworks/base/framework-minus-apex/android_common/xref30/srcjars.xref/android/os/IMessenger.java;drc=master;bpv=1;bpt=1;l=66?gsn=int&gs=kythe%3A%3Flang%3Djava%23int%23builtin) [flags](https://cs.android.com/android/platform/superproject/+/master:out/soong/.intermediates/frameworks/base/framework-minus-apex/android_common/xref30/srcjars.xref/android/os/IMessenger.java;drc=master;bpv=1;bpt=1;l=66?gsn=flags&gs=kythe%3A%2F%2Fandroid.googlesource.com%2Fplatform%2Fsuperproject%3Flang%3Djava%3Fpath%3Dandroid.os.IMessenger.Stub%236eb57c102109dcdc0f421974288d58fcfdd7c0cece91227464f748a5f62da177)) 

 服务端通过code可以确定客户端所请求目标的方法是什么,接着从data中取出目标方法所需的参数(如果目标方法有多数的话),然后执行目标方法,当目标方法执行完毕后,就向reply中写入返回值(如果目标方法有返回值的话),onTransact方法的执行过程就是这的。需要注意的是,如果此方法返回false,那么客户端的请求会失败,因为我们可以利用这个特性来做权限的验证,毕竟我们也不希望随便一个进程都能远程调用我们的服务。

## 使用Bundle

四大组件中的三大组件(Activity,Service,Receiver)都是支持在Intent中传递Bundle数据的，由于Bundle实现了Parcelable接口,所以它可以方便地在不同的进程间传输。当然，我们传输数据必须是能够被序列化。比如基本类型，实现了Parcelable接口的对象,实现了Serializable接口的对象以及一些Android支持的特殊对象。Bundle不支持的类型我们无法通过他在进程间传递数据。

## 使用文件共享

共享文件也是一种不错的进程间通讯方式，两个进程通过读/写同一个文件来交换数据，比如A进程把数据写入文件,B进程通过读取这个文件来获取数据。Windows上,一个文件如果被加了排斥锁将会导致其他线程无法对其进行访问，包括读和写，而由于Android系统基于Linux，使得其并发读/写文件可以没有限制地进行，甚至两个线程同时对同一个文件进行写操作都是允许的。

弊端:如果并发读/写，我们读出的的内容就有可能不是最新的，如果是并发写的话就更严重了。

## 使用Messenger和AIDL

Messenger可以翻译为信使,顾名思义,通过它可以在不同进程中传递Message对象,Messenger是一种轻量级的IPC方案,它的底层是AIDL。

```
public Messenger(Handler target) {
    mTarget = target.getIMessenger();
}
```

```
public Messenger(IBinder target) {
    mTarget = IMessenger.Stub.asInterface(target);
}
```

从构造方法上来看IMessenger还是asInterface方法都是表明它们底层是AIDL。

它对AIDL进行封装,使得我们可以更简单地进行进程间通信。同时,由于它一次处理一个请求,因为在服务端我们不用考虑线程同步问题。

RemoteCallBackListener；