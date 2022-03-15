# 问：讲下equals和hashcode，他们为何必须一起重写？hashcode方法重写规则。

## equals和hashCode(哈希码)实什么？

`equlas`方法和`hashCode`方法都是`Object`类的方法，equals在源码里是比较两个对象的地址值是否相同,`hashCode`是通过将内存地址转换成Int值。

## equlas方法

```
public boolean equals(Object obj) {
    return (this == obj);
}
```

没有重写`equlas`方法的情况下就是单纯比较内存地址。

## hashCode方法

```
   public int hashCode() {
        return identityHashCode(this);
    }
     
   static int identityHashCode(Object obj) {
        int lockWord = obj.shadow$_monitor_;
        final int lockWordStateMask = 0xC0000000;  // Top 2 bits.
        final int lockWordStateHash = 0x80000000;  // Top 2 bits are value 2 (kStateHash).
        final int lockWordHashMask = 0x0FFFFFFF;  // Low 28 bits.
        if ((lockWord & lockWordStateMask) == lockWordStateHash) {
            return lockWord & lockWordHashMask;
        }
        return identityHashCodeNative(obj);
    }
    
 private static native int identityHashCodeNative(Object obj);
```

可以简单得出`hashCode`会返回一个int(通过内存地址生成的int)值

## `equlas`和`hashCode`的作用和关系

当重写equals方法后有必要将`hashCode`方法也重写，这样做才能保证不违背`hashCode`方法中“相同对象必须有相同哈希值”的约定



## HashCode方法重新规则

- 两个对象相等，hashCode 一定相等
- 两个对象不等，hashCode 不一定不等
- hashCode 相等，两个对象不一定相等
- hashCode 不等，两个对象一定不等



## equals方法和hashCode方法会在哪用到

HashMap后面复习总结。