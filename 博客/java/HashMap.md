# HashMap

## HashMap是什么

在java1.8中`HashMap`是有数组+链表+红黑树组合构成的数据结构,链表长度超过8时会转化成红黑树。

`HashMap`它根据键的`hashCode`值存储数据，大多数情况下可以直接定位倒它的值，因而具有很快的访问速度,但便利顺序是不确定的。`HashMap`最多只允许一条记录的键为null,允许多条记录的值为`null`。`HashMap`非线程安全，即任意时刻可以有多个线程同时写`HashMap`，可能会导致数据的不一致，如果需要满足线程安全，可以用`Collecionts`的`synchronized`方法使HashMap具有线程安全的能力，或者使用`ConcurrentHashMap`。

## hash方法细节

```
static final int hash(Object key) {
    int h;
    return (key == null) ? 0 : (h = key.hashCode()) ^ (h >>> 16);
}
```

从代码上来看当`key==null`直接执行`Object`基类的hashCode生成哈希值的方法，重点就是当key不为`null`的时候通过`object`的hashCode方法生成哈希值并且右移16位

**注意:当hash算法计算结果越分散均匀，Hash碰撞的概率越小，存取效率就会越高**

**如果遇到哈希冲突怎么办？**

解决哈希冲突的办法有两种

**开放寻址法**

开放寻址法：又称开放定址法，当哈希碰撞发生时，从发生碰撞的那个单元起，按照一定的次序，从哈希表中寻找一个空闲的单元，然后把发生冲突的元素存入到该单元。 这个空闲单元又称为开放单元或者空白单元。 查找时，如果探查到空白单元，即表中无待查的关键字，则查找失败

**链地址法**

链地址法:数组加链表组合，在每个数组元素上都是一个链表结构，当key被hash后，得到数组下标,把数组放在对应下标元素的链表上。

## 扩容的触发条件

扩容的触发条件通过一个叫(threshold)阈值的参数控制的,阈值的计算公式是数组长度threshold(阈值)=capacity(容量)*loafFactor(负债因子)。

**容量**:默认是16长度,增长是旧数组长度*2。

**负债因子**:规定什么时候扩容的重要条件。

## Hashmap扩容机制？

通过源码解释

```
final Node<K,V>[] resize() {
    //获取旧数组的引用
    Node<K,V>[] oldTab = table;
    int oldCap = (oldTab == null) ? 0 : oldTab.length;
    int oldThr = threshold;
    int newCap, newThr = 0;
    if (oldCap > 0) {
         //当健值容量已经达到最大
        if (oldCap >= MAXIMUM_CAPACITY) {
            threshold = Integer.MAX_VALUE;
            //直接返回数组最大值
            return oldTab;
        }
        //没有超过最大值，扩充为原来的2倍
        else if ((newCap = oldCap << 1) < MAXIMUM_CAPACITY &&
                 oldCap >= DEFAULT_INITIAL_CAPACITY)
            newThr = oldThr << 1; // double threshold
    }
    else if (oldThr > 0) 
        //初始化容量赋值阀值
        newCap = oldThr;
    else {      
      // 初始化默认值
        newCap = DEFAULT_INITIAL_CAPACITY;
        newThr = (int)(DEFAULT_LOAD_FACTOR * DEFAULT_INITIAL_CAPACITY);
    }
    //新的阀值==0重新resize
    if (newThr == 0) {
        float ft = (float)newCap * loadFactor;
        newThr = (newCap < MAXIMUM_CAPACITY && ft < (float)MAXIMUM_CAPACITY 	?(int)ft : Integer.MAX_VALUE);
    }
    //重新给阀值赋值
    threshold = newThr;
    @SuppressWarnings({"rawtypes","unchecked"})
    //创建一个新的数组
    Node<K,V>[] newTab = (Node<K,V>[])new Node[newCap];
    table = newTab;
    if (oldTab != null) {
          //把每个桶里的数据转移到新的桶里
        for (int j = 0; j < oldCap; ++j) {
            Node<K,V> e;
            //给e赋值
            if ((e = oldTab[j]) != null) {
                //清除老数组的索引
                oldTab[j] = null;
                if (e.next == null)
                    //重新生成下标并把数据放入对应下标数组里
                    newTab[e.hash & (newCap - 1)] = e;
                else if (e instanceof TreeNode)
                   //给红黑树赋值
                    ((TreeNode<K,V>)e).split(this, newTab, j, oldCap);
                else { // 链表大于8小于1
                    Node<K,V> loHead = null, loTail = null;                
                    Node<K,V> hiHead = null, hiTail = null;
                    Node<K,V> next;
                    do {
                        next = e.next;
                        //原索引
                        if ((e.hash & oldCap) == 0) {
                            if (loTail == null)
                                loHead = e;
                            else
                                loTail.next = e;
                            loTail = e;
                        }
                        else {
                            if (hiTail == null)
                                hiHead = e;
                            else
                                hiTail.next = e;
                            hiTail = e;
                        }
                    } while ((e = next) != null);
                    //原索引放到桶里
                    if (loTail != null) {
                        loTail.next = null;
                        newTab[j] = loHead;
                    }
                    //原索引+oldcap放到桶里
                    if (hiTail != null) {
                        hiTail.next = null;
                        newTab[j + oldCap] = hiHead;
                    }
                }
            }
        }
    }
    return newTab;
}
```

**经过观测可以发现，我们使用的是2次幂的扩展(指长度扩为原来2倍)，所以，元素的位置要么是在原位置，要么是在原位置再移动2次幂的位置。**



## 链表转红黑树的阈值为何是8？链表为何要转红黑树？

jdk1.7是通过数组和链表组成，jdk1.8链表添加红黑树。

首先红黑树优势增删改查效率高链表数据量很大的事情如果通过红黑树进行操作会提高行能。

但是链表转换红黑树是耗时操作需要链表的遍历和红黑树的插入,转换后的性能要大于成本才算合理,阀值设置8应该是google开发工程严格进行系统测试均衡时间和空间复杂度后得出的值。

## HashMap添加元素的过程

```
  public V put(K key, V value) {
  		//对key的hashCode做hash
    return putVal(hash(key), key, value, false, true);
   }
   
    static final int hash(Object key) {
        int h;
        return (key == null) ? 0 : (h = key.hashCode()) ^ (h >>> 16);
    }

final V putVal(int hash, K key, V value, boolean onlyIfAbsent,
               boolean evict) {
    Node<K,V>[] tab; Node<K,V> p; int n, i;
    //1.tab为空则创建
    if ((tab = table) == null || (n = tab.length) == 0)
        n = (tab = resize()).length;
        //2.计算index，并对null做处理
    if ((p = tab[i = (n - 1) & hash]) == null)
        tab[i] = newNode(hash, key, value, null);
    else {
        Node<K,V> e; K k;
        //3.节点key存在直接覆盖
        if (p.hash == hash &&
            ((k = p.key) == key || (key != null && key.equals(k))))
            e = p;
          //4.判断该链为红黑树
        else if (p instanceof TreeNode)
            e = ((TreeNode<K,V>)p).putTreeVal(this, tab, hash, key, value);
        else {//5.链表
            for (int binCount = 0; ; ++binCount) {
                if ((e = p.next) == null) {
                    p.next = newNode(hash, key, value, null);
                    //5.1链表长度大于8转换为红黑树进行处理
                    if (binCount >= TREEIFY_THRESHOLD - 1) // -1 for 1st
                        treeifyBin(tab, hash);
                    break;
                }
                //5.2链表中已存在且hash值和key值都相等，先获取引用，后面用来替换值
                if (e.hash == hash &&
                    ((k = e.key) == key || (key != null && key.equals(k))))
                    break;
                p = e;
            }
        }
        if (e != null) { // existing mapping for key
            V oldValue = e.value;
            if (!onlyIfAbsent || oldValue == null)
             //统一替换原来的值
            e.value = value;
            afterNodeAccess(e);
            //返回原来的值
            return oldValue;
        }
    }
    ++modCount;
     //步骤6.键值对数量超过阀值，扩容
    if (++size > threshold)
        resize();
    afterNodeInsertion(evict);
    return null;
}
```

## hashmap为何如此设计？

均衡空间和时间复杂度使性能最大化,hashmap有性能比较高的生成下标的哈希值方法通过链表法解决哈希碰撞jdk1.8引入红黑树这种企业级别的数据结构优化红黑树的查询和修改效率大大提高效率。

