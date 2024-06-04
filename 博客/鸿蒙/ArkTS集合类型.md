# ArkTS集合类型
## 线性容器
线性容器底层主要使用数组，链表结构。
### List
List底层通过单向链表实现，每个节点有一个指向后一个元素的引用。当需要查询元素时，必须从头遍历，插入，删除效率高，查询效率低，List允许元素为null。
List和LinkedList相比，LinkedList是双向链表，可以快速地在头尾进行增删，而List是单向链表，无法双向操作
推荐使用场景： 当需要频繁的插入删除时，推荐使用List高效操作。

### ArrayList
ArrayList是一种线性数据结构，底层基于数组实现。ArrayList会根据实际需要动态调整容量，每次扩容增加50%
ArrayList和Vector相似，都是基于数组实现。它们都可以动态调整容量，但Vector每次扩容增加1倍。
ArrayList和LinkedList相比，ArrayList的随机访问效率更高。但由于ArrayList的增删操作会影响数组内其他元素的移动，LinkedList的增加和删除操作效率更高。
推荐使用场景： 当需要频繁读取集合中的元素时，推荐使用ArrayList。


### LinkedList
LinkedList底层通过双向链表实现，双向链表的每个节点都包含对前一个元素和后一个元素的引用。当需要查询元素时，可以从头便利，也可以从尾部遍历，插入，删除效率高，查询效率低。LinkedList允许元素为null。
LinkedList和List相比，LinkedList是双向链表，可以快速地在头尾进行增删，而List是单向链表，无法双向操作。
LinkedList和ArrayList相比，插入数据效率LinkedList优于ArrayList，而查询效率ArrayList优于LinkedList。
推荐使用场景：当需要频繁的插入删除时，推荐使用LinkedList高效操作。

### Deque
Deque(double ended queue)根据循环队列的数据结构实现，符合先进先出以及先进后出的特点，支持二端的元素插入和移除。
Deque和Queue相比，Queue的特点是先进先出，只能在头部删除元素，尾部增加元素。
与Vector相比，它们都支持二端增删元素，但D饿却不能进行中间插入的操作。对头部元素的插入删除效率高于Vector，而Vector访问元素的效率高于Deque。
推荐使用场景： 需要频繁在集合两端进行增删元素的操作时，推荐使用Deque。

### Queue
Queue的特点是先进先出，在尾部增加元素，在头部删除元素。根据循环队列的数据结构实现。
Queue和Deque相比，Queue只能在一端删除一端增加，Deque可以两端增删。
推荐使用场景:一般符合先进先出的场景可以使用Queue。

### Stack
Stack基于数组的数据结构实现，特点是先进后厨，只能在一端进行数据的插入和删除。
Stack和Queue相比，Queue基于循环队列实现，只能在一端删除，另一端插入，而Stack都在一端操作。
推荐使用场景: 一般符合先进后厨的场景使用Stack。

## 非线性容器

### HashMap
HashMap底层使用数据+链表+红黑树的方式实现，查询，插入和删除的效率都很高。Hashmao存储基于key-value的键值对映射，不能有重复的key，且一个key只能对应一个value。
HashMap和TreeMap相比，hashMap依据键的hashCode存储数据，访问速度较快。而TreeMap是有序存取，效率较低。
HashSet基于hashMap实现。HashMap的输入参数由key，value二个值组成。在HashSet中，只对value对象进行处理。
推荐使用场景:需要快速存取，删除以及插入键值对数据时，推荐使用hashMap。

### HashSet
hashSet基于HashMap实现。在HashSet中，只对value对象进行处理。
HashSet和TreeSet相比，HashSet中的数据无序存放，即存放元素的顺序和取出的顺序不一致，而TreeSet是有序存放。它们集合中的元素都不允许重复，但HashSet允许放入null值，TreeSet不建议插入空值，可能会影响排序结果。
推荐使用场景:可以利用HashSet不重复的特性，当需要不重复的集合或需要去重某个集合的时候使用。

### TreeMap
TreeMap可用于存储具有关联关系的key-value键值对集合，存储元素中key值唯一，每个key对应一个value。
TreeMap底层使用红黑树实现，可以利用二叉树特性快速查找键值对。key值有序存储，可以实现快速的插入和删除。
TreeMap和HashMap相比，HashMap依据键的hashCode存储数据，访问速度较快。而TreeMap是有序存取，效率较低。

### TreeSet
TreeSet基于TreeMap实现，在TreeSet中，只对value对象进行处理。TreeSet可以用于存储一系列值的集合，元素中value唯一且有序。
TreeSet和hashSet相比，HashSet中的数据无序存放，而TreeSet是有序存放。它们集合中的元素都不允许重复，但hashSet允许放入null值，TreeSet不建议插入空值，可能会影响排序结果。
