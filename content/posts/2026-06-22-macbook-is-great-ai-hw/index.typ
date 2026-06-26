#import "/config.typ": template, tufted
#show: template.with(
  title: "macBook是很棒的AI终端",
  date: datetime(year: 2026, month: 6, day: 22),
)

这件事应该是很广为人知的；但是这里的AI不是LLM，我这里要谈论的也不是在macBook上部署一个3B的LLM。

先简单讲一下苹果电脑的统一内存：苹果电脑里面的计算硬件包括CPU,GPU,NPU，其中NPU目前用户暂时不可编程，但是CPU和GPU都可以直接读取统一内存上的数据，不需要像PC那样经过PCI-E从CPU管理的内存传输到显卡上的显存；因此
- 如果你的macBook的内存有32G，那他可以跑推理的模型种类就已经吊打那些显存只有8\~12G的中端NVIDIA GPU了；可能跑的慢一点，但是不会因为内存不足而崩溃掉；
- Apple的GPU是很编程友好的，有高级别抽象的库MLX可以用；
- Apple GPU的功耗相比于移动版的NVIDIA GPU可以算很小的，能支持几十到小几百M参数的模型常驻内存，在需要的时候跑推理。

这样的话，其实很多开源模型其实就可以派上用场了，尤其是一些延迟不敏感，但是又比较大（< 1B）的模型，比如：

- 当同事发来一张图而你需要里面的文字的时候，可能会需要OCR模型；
- 人声-伴奏音轨分离、人声转MIDI，这种模型都是几到几十M，都可以直接部署在本地；
- 装一个基于RVC的变声器，就可以直接用自己的声音来prototype歌曲的男女合唱or和声。

另一个优势是苹果的GPU有很方便的编程接口MLX，再加上现在强大的Coding Agent，如果深度学习模型我感觉可以集成到我的日常生活中，可以直接让Coding Agent把PyTorch翻译成MLX Python，甚至是翻译成MLX C，然后直接做一个app或者接入到已有的app里面（任何语言都应该需要可以interop with C），然后我们就可以稳定使用这个模型的能力了！拜LLM所赐，不好商业化的开源前沿研究成果，也可以快速被广泛地应用。
