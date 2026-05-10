#import "/config.typ": template, tufted
#show: template.with(
  title: "Lsm Tree 实现备注",
  description: "Lsmkv 实现过程中的技术备注",
  date: datetime(year: 2025, month: 3, day: 1),
)

= Lsm Tree 实现备注

这是我实现 #link("https://github.com/Da1sypetals/Lsmkv")[Lsmkv] 的时候记录的备注。

== 组件

- 内存部分
- 磁盘部分
- WAL

== 总体

=== 初始化

需要 init flush thread。flush thread 的工作流程:
1. 等待 flush 信号量被 notify,获取一个 compact 信号量资源
2. 启动一个 sstwriter,写入这个 memtable
3. 等到写入 sst 写完之后,才进行:
   - 从 frozen memtables、frozen memtable sizes 里面删除这个 memtable
   - 从 wal 里面删除这个 memtable 对应的 wal
   - update manifest

=== Try Freeze

如果当前大小 > freeze size 那么就 freeze;进一步如果所有 frozen memtable 大小之和 > flush threshold,那么就 set flush signal。

=== 写操作

1. 写 memtable
2. 写 WAL
3. try freeze

== 内存部分

=== Put

1. 添加到 memtable;
2. 更新 size。

=== Delete

1. 添加一个 tomb 标记到 memtable

=== Get

1. 从 active memtable 中获取
2. 从 new 到 old 遍历所有的 inactive memtable,获取。

== 磁盘部分

=== compact 信号量

二元信号量。

=== Level

存储这个 level 所有文件对应的文件路径,装在 sst reader 里面

=== Get

从低到高,从新到旧,调用 sst 的 get 方法,获取 record。否则返回 none。

=== Compact

以 L0 -> L1 为例:
从前到后遍历所有的 kv-pair,同时维护:
1. keys_outdated
2. L1 sst size 每达到一定值就关闭当前 sst,新开一个新的 sst。
3. 更新 manifest。

=== SST writer

配置 max block size。
- 每个 block 的开头一个 key 会添加到 index 中;
- 搜索这个 sst 的时候,会先对 index 进行二分查找;
- 在 block 之内采用线性搜索。

fpr,用于构建 bloom filter.

==== 写入

1. 遍历所有的 kv pair:
   - userkey(不含 timestamp)添加到 bloom filter;
   - block 写入当前 kv;
   - 如果当前 block 大小超过 max block size,就开启一个新的 block
2. 将 index 和 bloom filter 写磁盘。

==== SST reader 查找

1. 查 bloom filter,如果不存在就返回。
2. 将 index 整个载入内存中,进行二分查找
3. 按照查找到的区间,读磁盘。

== MVCC

=== key 排布问题

==== struct Key

- bytes
- timestamp: u64

比较: key1 < key2:
- key1.bytes < key2.bytes (字典序);
- 或者: key1.bytes == key2.bytes,而且 key1.timestamp > key2.timestamp

==== 为什么这样比较?

在进行查询 Get(userkey, timestamp) 的时候,我们需要的是:
- userkey 匹配
- timestamp 小于查询的 timestamp,且尽可能大

因此,我们将
- userkey 升序排序
- timestamp 降序排序

== Transaction

=== 数据结构

一个内存 tempmap,用来存储 transaction 已经写,但是未提交的内容。

=== Put,Delete

写 tempmap,写 WAL

=== Get

使用 start timestamp,先查 tempmap,再查 tree。

=== Commit

1. 从 tree 获取一个 commit timestamp;
2. 写 WAL,记录 transaction id 和 commit timestamp。
3. 调用 tree.active_memtable 的 API,将 transaction 的所有数据写入 tree 的 memtable。

== 踩坑

1. Resource deadlock avoided (os error 35),可能是一个 thread 持有了自己的 joinhandle 并且 join 了自己。
2. 死锁问题: wal 和 mem 都有锁,必须按照同一顺序获取才不会出现死锁。

== Bloom filter 细节

该 Bloom filter 算法的主要步骤如下:

1. 参数计算:
   - $ m=ceil(-n ln(p) / ln(2)^2) $
   - $ k=ceil((m/n) ln(2)) $

2. 哈希生成:
   - 使用 64 位指纹哈希(farmhash)生成初始哈希值 h
   - 通过位运算构造增量值 `delta = (h >> 33) | (h << 31)`
   - 采用双重哈希技术: $ h_i equiv h + i dot delta mod m $

3. 数据插入与存在性检测

4. 数据持久化:
   - 序列化时附加 CRC32 校验和
