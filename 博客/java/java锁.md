# java锁

## 乐观锁和悲观锁

**悲观锁：**对于同一个数据的并发操作，悲观锁认为自己再使用数据的时候可能会有别的线程来修改数据，因此再获取数据的时候会先加锁，确保数据不会被别的线程修改。Java中，synchronized关键字和Lock的实现类都是悲观锁。

**乐观锁：**乐观锁认为自己再使用数据时不会有别的线程修改数据，所以不会添加锁，知识在更新数据的时候去判断之前有没有别的线程更新了这个数据。如果这个数据没有被更新，当前线程将自己修改的数据成功写入。如果数据一家被其他线程更新，则根据不同的实现方式执行不同的操作（例如报错或者自动重试）。

乐观锁在Java中是通过使用无锁编程来实现，最常采用的时CAS算法，Java原子类中的递增操作就通过CAS自旋实现的。

![图片](https://mmbiz.qpic.cn/mmbiz_png/hEx03cFgUsXibicYtRt824nicRjKGTibicl7ayRG0ezibGQf6E0G7XqoS0MlVNPhdjwcsMIfFCibVpQLia3MsFp31nDTwg/640?wx_fmt=png&tp=webp&wxfrom=5&wx_lazy=1&wx_co=1)

- 悲观锁适合写操作多的场景，先加锁可以保证写操作时数据正确。
- 乐观锁适合读操作多的场景，不加锁的特点能够使其读操作的性能大幅提示。

**CAS：**CAS时一种无锁算法，CAS有三个操作数，内存值V，旧的预期值A，要修改的新值B。当且仅当预期值A和内存值V相同时，将内存值V修改为B，否则什么都不做。