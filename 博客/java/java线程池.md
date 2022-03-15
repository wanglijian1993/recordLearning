# java线程

## 1.线程的几种状态

1. **初始(new)**:新创建了一个线程对象,但还没有调用start()方法。
2. **运行(RUNNABLE)**:Java线程中将就绪(ready)和运行中(running)两种状态笼统的称为"运行"。线程对象创建后，其它线程（比如main线程）调用了该对象的`start()`方法。该状态的线程位于可运行池中，等待被线程调度选中，获取CPU的使用权，此时处于就绪状态（ready）。就绪状态的线程在获取CPU时间片后变为可运行中状态（running）。
3. **阻塞（BLOCKED）**：表示线程组赛于锁。
4. **等待（WAITING）**：进入该状态的线程需要等待其他线程做出一些特定动作（通知或中断）。
5. **超时等待(TIMED_WAITING)**:该状态不同于WAITING,它可以在指定的时间后自行返回。
6. **终止(TERMINATED)**:表示该线程已经执行完毕。

![线程状态图](https://img-blog.csdnimg.cn/20181120173640764.jpeg?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3BhbmdlMTk5MQ==,size_16,color_FFFFFF,t_70)

## 2.1线程池是什么

线程池(Thread pool) 是一种基于池化思想管理线程的工具,经常出现多线程服务器中，如MySql

线程过多会带来额外的开销，其中包括创建销毁线程的开销，调度线程的开销等等，同时也降低了计算机的整体性能。线程池维护多个线程，等待监督管理者分配可并发执行的任务。这种做法，一方面避免了处理任务时创建销毁线程开销的代价，另一方面避免了线程数量膨胀导致的过分调度问题，保证了对内核的充分利用。

**线程池的好处**

- **降低资源消耗**：通过池化技术重复利用已创建的线程，降低线程创建和销毁造成的损耗。
- **提高响应速度**：任务到达时，午需等待线程创建即可立即执行
- **提高线程的可管理性**：线程是稀缺资源，如果无限制创建，不仅会消耗系统资源，还会因为线程的不合理分布导致资源调度失衡，降低系统的稳定性，使用线程池可以进行统一的分配，调度和监控。
- **提供更多更强大的功能**：线程池具备可扩展性，允许开发人员向其中增加更多的功能，比如延时定时线程池ScheduledThreadPoolExecutor，就允许任务延期执行或定期执行。

## 2.1线程池解决的问题实什么

线程池解决的核心问题就是资源管理问题。在并发环境下，系统不能够确定下任意时刻中，有多少任务需要执行，有多少资源需要投入。这种不确定性将带来一下若干问题。

1. 频繁申请/销毁资源和调度资源，将带来额外的消耗，可能会非常巨大。
2. 对资源无限申请缺少抑制手段，易引发系统资源耗尽风险。
3. 系统无法合理管理内部的资源分布，会降低系统的稳定性。

**池化思想：**为了最大化收益并最小化风险，而将资源统一在一起管理的一种思想。



## 3.1线程池核心设计与实现

ThreadPoolExecutor的UML类图

![图1 ThreadPoolExecutor UML类图](https://p1.meituan.net/travelcube/912883e51327e0c7a9d753d11896326511272.png)

ThreadPoolExecutor实现的顶层接口是Executor,顶层接口Executor提供了一种思想:将任务提交和任务执行进行解耦。用户无需关注如何创建线程，如果调度线程来执行任务，用户只需要提供Runable对象，将任务的运行逻辑提交到执行器（Executor）中，由Executor框架完成线程的调配和任务的执行部分。

ExecutorService接口增加了一些能力

1. 扩展执行任务的能力，补充可以为一个或一批异步任务生成Future的方法。
2. 提供了管控线程池的方法，比如停止线程池的运行。

AbstractExecutorService则是上层的抽象类，将执行任务的流程串联了起来，保证下层的实现只需关注一个执行任务的方法即可。最下层的实现类ThreadPoolExecutor实现最复杂的运行部分。

ThreadPoolExecutor运行流程图

![图2 ThreadPoolExecutor运行流程](https://p0.meituan.net/travelcube/77441586f6b312a54264e3fcf5eebe2663494.png)

线程池在内部实际上构建了一个生产者消费者模型，将线程和任务两者解耦，并不直接关联，从而良好的缓冲任务，复用线程。线程池运行主要分成两部分：**任务管理，线程管理**。任务管理部分充当生产者的角色，当任务提交后，线程池会判断该任务后续的流转：

1. 直接申请线程执行该任务
2. 缓冲到队列中等待线程执行
3. 拒绝该任务

线程管理部分是消费者，它们被统一维护在线程池内，根据任务请求进行线程分配，当线程执行完任务后则继续获取新的任务去执行，最终当线程获取不到任务的时候，线程就会被回收

接下来，我们会按照以下三个部分去详细讲解线程池运行机制

1. 线程池如果维护自身状态
2. 线程池如果管理任务
3. 线程池如果管理线程

## 3.2生命周期管理

线程池运行的状态，并不是用户显示设置的，而是伴随着线程池的运行，由内部来维护。线程池内部使用一个变量维护两个值：运行状态（runState）和线程数量（workerCount）。在具体实现中，线程池将运行状态（runState），线程数量（workerCount）两个关键参数的维护放在了一起

```
private final AtomicInteger ctl = new AtomicInteger(ctlOf(RUNNING, 0));

    private static final int RUNNING    = -1 << COUNT_BITS;
    private static final int SHUTDOWN   =  0 << COUNT_BITS;
    private static final int STOP       =  1 << COUNT_BITS;
    private static final int TIDYING    =  2 << COUNT_BITS;
    private static final int TERMINATED =  3 << COUNT_BITS;
    
 rivate static final int COUNT_BITS = Integer.SIZE - 3;
```

`ctl`这个AtomicInteger类型，是对线程池运行状态和线程池中有效线程的数量进行控制的一个字段，它同时包含两部分的信息：线程池运行状态（runState）和线程数量（workerCount）。高3位保存runState，低29位保存workerCount，两个变量之间互不干扰。用一个变量去存储两个值，可避免在做相关决策时，出现不一致的情况，不必为了维护两者的一致，而占用锁资源。通过阅读线程池源代码也可以发现，经常出现要同时判断线程池运行状态和线程数量的情况。线程池也提高了若干方法去供用户获得线程池当前的运行状态，线程个数。这里都使用的是位运算方式，相比于基本运算，速度也会快很多。

```
//计算当前运行状态
private static int runStateOf(int c)     { return c & ~CAPACITY; }
//计算当前线程数量
private static int workerCountOf(int c)  { return c & CAPACITY; }
//通过状态和线程数生成ctl
private static int ctlOf(int rs, int wc) { return rs | wc; }
```

ThreadPoolExecutor的运行状态有5种

![img](https://p0.meituan.net/travelcube/62853fa44bfa47d63143babe3b5a4c6e82532.png)

生命周期转换如下图

![图3 线程池生命周期](https://p0.meituan.net/travelcube/582d1606d57ff99aa0e5f8fc59c7819329028.png)

## 2.3任务执行机制

**2.3.1任务调度**

任务调度是线程池主要入口，当用户提交了一个任务，接下来这个任务将如何执行都是由这个阶段决定的。线程池核心运行机制。

首先，所有任务的调度都是由execute方法完成的，这部分完成的工作是：检查现在线程池的运行状态，运行线程数，运行策略，决定接下来执行的流程，是直接申请线程执行，或是缓冲到队列中执行，亦或是直接拒绝该任务

执行过程如下：

1. 首先检查线程池运行状态，如果不是RUNNING，则直接拒绝，线程池要保证在RUNNING的状态下执行任务。
2. 如果workerCount<corePoolSize,则创建并启动一个线程来执行新提交的任务。
3. 如果workCount>=corePoolSize,且线程池内的阻塞队列未满，则将任务添加到阻塞队列中。
4. 如果workCount>=corePoolSize&&workCount<maxiNumPoolSize,且线程池阻塞队列已满，则创建并启动一个线程来执行新提交的任务。
5. 如果workerCount>=maxinumPoolSize,并且线程池内的阻塞队列已满，则根据拒绝策略来处理该任务，默认的处理方式是直接抛异常。

**任务调度流程**

![图4 任务调度流程](https://p0.meituan.net/travelcube/31bad766983e212431077ca8da92762050214.png)

**3.3.2任务缓冲**

任务缓冲模块是线程池能够管理任务的核心部分。线程池的本质是对任务和线程的管理，而做到这一点最关键的思想就是将任务和线程两者解耦，不让两者直接关联，才可以做后续的分配工作。线程池中是以生产者消费者模式，通过一个阻塞队列来实现的。阻塞队列缓存任务，工作线程从阻塞队列中获取任务。

阻塞队列(BlockingQueue)是一个支持两个附加操作的队列。这两个附加的操作是：在队列为空时，获取元素的线程会等待队列变为非空。当队列满时，存储元素的线程会等待队列可用。阻塞队列常用于生产者和消费者的场景，生产者时往队列里添加元素的过程，消费者时从队列里拿元素的线程。阻塞队列就是生产者存放元素的容器，而消费者也只从容器里拿元素。

**阻塞队列图**

![图5 阻塞队列](https://p1.meituan.net/travelcube/f4d89c87acf102b45be8ccf3ed83352a9497.png)

是不同的队列可以实现不一样的任务存取策略。阻塞队列成员

![img](https://p0.meituan.net/travelcube/725a3db5114d95675f2098c12dc331c3316963.png)

**3.3.3任务申请**

有上下文的任务分配部分可知，任务的执行有两种可能：一种时任务直接由新创建的线程执行，另一种时线程从任务队列中获取任务然后执行，执行完任务的空闲线程会再次去从队列中申请任务再去执行。第一种情况仅出现再线程初始创建的时候，第二种时线程获取任务绝大多数的情况。

线程需要从任务缓存模块中不断地取任务执行，帮助线程从阻塞队列中获取任务，实现线程管理模块和任务管理模块之前的通信。这部分策略有getTask方法实现。

执行流程图

![图6 获取任务流程图](https://p0.meituan.net/travelcube/49d8041f8480aba5ef59079fcc7143b996706.png)

getTask这部分进行了多次判断，为的是控制线程的数量，使其符合线程池的状态。如果线程池现在不应该持有那么多线程，则返回null值。工作线程worker会不断接受新任务去执行，而当工作线程Worker接收不到任务的时候，就会开始被回收。

## 2.3.4任务拒绝

任务拒绝模块是线程池的保护部分，线程池有一个最大的容量，当线程池的任务缓存队列已满，并且线程池中的线程数目达到maxinumPoolSize时，就需要拒绝掉该任务，采取任务拒绝策略，保护线程池。

拒绝策略是一个接口，其设计如下：

 

```
public interface RejectedExecutionHandler {
    void rejectedExecution(Runnable r, ThreadPoolExecutor executor);
}
```

jdk提供四种已有拒绝策略

![img](https://p0.meituan.net/travelcube/9ffb64cc4c64c0cb8d38dac01c89c905178456.png)

## 2.4 worker线程管理

**2.4.1Worker线程**

线程池为了掌握线程的状态并维护线程的生命周期，设计了线程池内的工作线程Worker。

```
private final class Worker
    extends AbstractQueuedSynchronizer
    implements Runnable
{
    final Thread thread;
    Runnable firstTask;
    }
```

Worker这个工作线程，实现了Runable接口，并持有一个线程thread，一个初始化任务的firstTask，thread时调用构造方法时通过ThreadFactory来创建的线程，可以用来执行任务，firstTAsk用它来保存传入的第一个任务，这个任务可以有也可以为null。如果这个值是非空的，那么线程就会再启动初期立即执行这个任务，也就对应核心线程创建时的情况，如果这个值时null，那么就需要创建一个线程去执行任务列表(workQueue)中的任务，也就是非核心线程的创建。

Worker执行任务的模型

![图7 Worker执行任务](https://p0.meituan.net/travelcube/03268b9dc49bd30bb63064421bb036bf90315.png)

线程池需要管理线程的生命周期，需要在线程长时间不运行的时候进行回收。线程池使用一张Hash表去持有线程的引用，这样可以通过添加引用，移除引用这样的操作来控制线程的生命周期。这个时候重要的就是如何判断线程是否允许。

Worker时通过继承AQS，使用AQS来实现独占锁这个功能。没有使用可重入锁ReentrantLock，二是使用AQS，维地就是实现不可重入的特性去反应线程现在的执行状态。

lock方法一旦获取独占锁，表示当前线程正在执行任务中。

如果正在执行任务，则不应该中断线程。

如果该线程现在不是独占锁的状态，也就是空闲的状态，说明它没有再处理任务，这时可以对该线程进行中断。

线程池再执行stutdown方法或tryTerminate方法时会调用interruptIdleWorkers方法来中断空闲的线程，再线程回收过程中就使用到了这种特性。

回收过程入下图

![图8 线程池回收过程](https://p1.meituan.net/travelcube/9d8dc9cebe59122127460f81a98894bb34085.png)

## 3.4.2Worker线程增加

增加线程时通过线程池的adddWorker方法，该方法的功能就是增加一个线程，该方法不考虑线程池时在哪个阶段增加的该线程，这个分配线程的策略是在上个步骤完成的，该步骤仅仅完成增加线程，并使它允许，最后返回是否成功这个结构。addWorker方法有两个参数：firstTask，core，firstTask参数用于指定新增的线程执行第一个任务，该参数可以为空，core参数为ture表示新增线程时会判断当前活动线程是否少于corePoolSize，false表示新增线程前需要判断当前活动线程是否少于maxinumPoolSize