#import "/book.typ": book-page
#show: book-page.with(title: "Sample Page")
 

// ################### Content ###################

= Triton 踩坑

== 垃圾的文档

最近工作上需要优化一个自定义算子，用到了OpenAI triton。但是查阅资料后，发现triton这个库的*文档*简直是 *数一数二的垃圾*，就像那种只有数学公式，没有代码的论文一样。

个人认为，既然计算以tensor为单位的，就要把这个操作对应的输入、输出tensor形状写出来，然后给一个具体的例子，参考PyTorch的文档。而不是全都用自然语言来描述。

==== triton是怎么做的呢？

举个例子：https://triton-lang.org/main/python-api/generated/triton.language.load.html#triton.language.load

这是`tl.load` 的文档。里面提到了用Block pointer可以用 boundary check和padding option。
- 第一个问题就来了，boundary check是做什么？是out of bounds就不加载了，获得一个比Block shape更小的tensor？还是用某个值填满？还是运行时报错？还是什么别的操作？
- 接下来就是padding option的问题：这个padding指的是什么？然后还需要靠自己猜才知道，这个padding指的就是那些out of bounds的元素。
这里我是可以猜出来的，但 *这本来应该是文档应该explicit写出来的，而不是用户来猜的。*

再比如，`tl.make_block_ptr` 和 `tl.arange`，这里的block shape的每个维度、和arange的元素个数，都必须是2的整数次幂。*这点居然没有在任何文档中体现出来，简直匪夷所思。*最后我是从代码报错中发现这个限制的，然后我去全网google，在一篇非官方的、对triton进行讨论和benchmark的#link("https://fkong.tech/posts/2023-04-23-triton-cuda/", "博客")里面看到了这个限制。

*总结来说，给triton写文档的人是真的对不起那帮做编译器的人。*

== 一些API和参数的clarify
- `tl.load` 
  - 如果你使用的是裸指针/很多裸指针组成的tensor，请*同时设置mask和other参数*。
    - mask为True代表这个位置要从hbm加载；False代表使用other的值。
    - other是一个浮点数。
    如果你是用的是`tl.make_block_ptr`创建的指针，请*同时设置所有维度的boundary check，然后把padding option设置为zero.*这样可以减少bug出现的概率，因为我们并不知道boudary check这个参数的semantics是怎么样的，尤其是在make block pointer设置了维度的顺序order之后。

- `tl.arange`的元素个数、`tl.make_block_ptr` 的block shape都必须是2的整数次幂。或许任何`triton` tensor的每个维度都需要时2的整数次幂，但是我并没有进行测试。
- `tl.load` 和 `tl.store` 的invalid memory access 都会导致tensor里面有的东西变成nan。*没错，你没有看错，`tl.store` 也会*，不知道为什么，因为你访问了非法地址，原来合法的地址里面存的东西也变成了nan！除非你保证你处理的维度都是64的倍数，否则请务必在从HBM读写数据的时候，把边界检查开起来。
  - 如果你是用的是裸指针，更要*小心设置mask*。