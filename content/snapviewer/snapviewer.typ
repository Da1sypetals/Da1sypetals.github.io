#import "/book.typ": book-page
#show: book-page.with(title: "Sample Page")


// ################### Content ###################
#let memviz = link("https://docs.pytorch.org/memory_viz", "这个网站")

= SnapViewer

- PyTorch 在训练模型的时候常常会OOM，这时候就需要对显存进行优化。当一些简单的方法（降低batchsize等）以及行不通的时候，可能就需要对模型本身的显存轨迹进行分析。


- 这时候你会看到#link("https://docs.pytorch.org/docs/stable/torch_cuda_memory.html", "这个文档")，他会教你如何记录memory snapshot 并且在 #memviz 上进行可视化。

- 但是有一个很大的问题是：#memviz 太卡了。如果你的模型很小，snapshot只有几个MB，流畅度还算能看；如果你的模型比较大，snapshot达到几十甚至几百MB，那么这个网站就会变得非常卡，帧率最低可达每分钟两三帧。

- 我去看了这个网站的js代码，它主要做了这些事：
  + 手动加载python pickle文件；
  + 每一帧都重新将原数据解析为图形，然后再每一帧渲染到屏幕上。
  这个渲染逻辑是用js写的，因此性能嘛...

- 我在对一个几B参数量的模型进行snapshot的时候发现了这个问题。
  - 为什么需要自己优化，而不是用现成的LLM基础设施？长话短说，这个模型是researcher自己设计的，里面含有大量的和LLM完全不同的模块。现在好像大家默认深度学习只剩下LLM了，以至于甚至有些tech lead都认为LLM的基础设施可以轻松接到很多其他模型上面...偏题了

- 我原本写了个简单的脚本用来解析snapshot里面的内容，尝试借此发现模型里面的显存分配问题；但是在我对着这个模型工作了一个月之后，我终于受不了了。于是有了这个项目：#link("https://github.com/Da1sypetals/SnapViewer", "SnapViewer").

- TLDR：将memory snapshot的图形解析出来，用一个巨大的triangle mesh表示，然后复用渲染库对mesh的渲染能力进行渲染。这是一个上百MB的snapshot，在我的集显上跑的还算流畅：

#image("snapviewer.gif")

如果你也有需要，欢迎试用一下: )

欢迎围观 & star！https://github.com/Da1sypetals/SnapViewer
