#import "/config.typ": template, tufted
#show: template.with(
  title: "赛博歌搭的探索历程记录",
  date: datetime(year: 2026, month: 8, day: 15),
)

最近需要一个搭子一起唱歌，但是在全民k歌冲浪了很久都没有找到搭子，于是想了想打算自己用AI做一个。

其中主要涉及到的技术就是SVC/SVS (Singing voice conversion/synthesis)。SVC是把一个人的歌声换成另一个人的；SVS是从曲谱和歌词（以及其他的唱法参数）生成一段歌声。

== 选择技术

从定义就可以很明显的看出SVS是老一代虚拟歌姬的AI-ify版本，在制作音乐的时候需要更多的手动调参，当然也更加可控；但是我是一个懒人，而且我还会点唱歌，我觉得这些手动调的唱法参数其实都可以用自己的嗓子做到（通过唱出不一样的输入音频来实现）。因此我选择了SVC这个方向。

让LLM Agent进行一波调研之后，发现现在研究的重点逐渐从2021～2023年的每个音色一个模型（主要例子有#link("https://github.com/svc-develop-team/so-vits-svc", "so-vits-svc")，#link("https://github.com/yxlllc/DDSP-SVC", "ddsp-svc")）；转换到现在追求zero-shot，也就是只需要给一段参考音频，就可以用参考音频的声音生成歌声（例子有#link("https://github.com/Plachtaa/seed-vc", "seed-vc"), #link("https://github.com/GiantAILab/YingMusic-SVC", "yingmusic-svc")）。

=== So-vits-svc
经过一个个的demo试听，一开始我实际上是认为音色和模型绑定的路线是更好的，因为b站上有大量的用(sovits/ddsp)-svc做AI翻唱的，听起来听感也不错。但是在把模型拉下来跑推理之后，我发现一个比较大的问题是，就算是质量更好的so-vits-svc，用GAN Generator生成出的音频电音比较严重[todo:audio]。我又换了好多个checkpoint，其中还有OpenCpop这种有一个人大量高质量干音数据集训练的，但是结果的电音都是相对比较严重的。

通过进一步阅读readme，了解到shallow diffusion model可能可以缓解电音问题。其具体工作方式是：
- 训练的时候，使用目标歌手的GT音频，通过加一个浅噪声，并且预测噪声，来学习[noisy mel -> clean mel]之间的分布transport；
- 推理的时候，对GAN Generator生成的音频添加对应的噪声，然后再用shallow diffusion模型denoise，期望降低电音。
但是初看这个方案就有一个很明显的训推不一致问题：
- 训练的时候使用的是GT音频；
- 推理的时候却期望对GAN生成的音频起作用。
实际跑完训练推理后，听感是diffusion带来了咬字不清的问题：在所有的辅音音节上，原本GAN输出的音频咬字比较清晰的，经过Diffusion之后就变得相当模糊，以至于让人经常听不清这一句唱了什么。

=== 补丁

由于我是先意识到训推不一致再听到辅音咬字不清的，因此我就下意识认为这个问题是和训推不一致有关的（现在我又再次无法确定这个问题是什么导致的了，希望有一天我能有空把这个问题捡起来研究清楚）。

基于[训推不一致]这个问题，我想找的解决方法至少需要满足以下条件：
- 训推一致：训练输入是GAN的输出音频；训练的GT是数据集的高质量干音；
- 充分利用已有checkpoint（由于so-vits-svc的底模训练包含了很多虚拟主播的授权数据集而我无法获取，因此我希望可以把训练好的权重以一个比较高的利用率转换到新的模型上）
因此，上述离散时间步的Diffusion model肯定没有办法用了，因为我们没有从GAN生成的noisy mel到GT mel的完整加噪路径的，因此获取每个训练step的训练数据对(noisy mel, noise)。

但是一个补丁正好就可以打在这个点上：基于Rectified flow的Flow Matching正好不需要整个加噪路径，其只需要采样一个时间t，并按照这个时间在noisy和GT之间插值，就可以作为训练对。





