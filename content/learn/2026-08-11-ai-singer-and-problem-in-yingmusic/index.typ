#import "/config.typ": template, tufted
#show: template.with(
  title: "赛博歌搭：探索记录",
  date: datetime(year: 2026, month: 8, day: 11),
)

最近需要一个搭子一起唱歌，但是在全民k歌冲浪了很久都没有找到搭子，于是想了想打算自己用AI做一个。

其中主要涉及到的技术就是SVC/SVS (Singing voice conversion/synthesis)。SVC是把一个人的歌声换成另一个人的；SVS是从曲谱和歌词（以及其他的唱法参数）生成一段歌声。

== 选择技术

从定义就可以很明显的看出SVS是老一代基于声库的虚拟歌姬的AI-ify版本#footnote[知名的开源方案包括 #link("https://github.com/openvpi/DiffSinger", "diffsinger") 等]，在制作音乐的时候需要更多的手动调参（包括f0曲线、音量、气声，甚至口型），当然也更加可控；但是我是一个懒人，而且我还会点唱歌，我觉得这些手动调的唱法参数其实都可以用自己的嗓子做到（通过唱出不一样的输入音频来实现）。因此我选择了SVC这个方向。

让LLM Agent进行一波调研之后，发现现在研究的重点逐渐从2021～2023年的每个音色一个模型（主要例子有#link("https://github.com/svc-develop-team/so-vits-svc", "so-vits-svc")，#link("https://github.com/yxlllc/DDSP-SVC", "ddsp-svc")）；转换到现在追求zero-shot，也就是只需要给一段参考音频，就可以用参考音频的声音生成歌声（例子有#link("https://github.com/Plachtaa/seed-vc", "seed-vc"), #link("https://github.com/GiantAILab/YingMusic-SVC", "yingmusic-svc")）。

== So-vits-svc
经过一个个的demo试听，一开始我实际上是认为音色和模型绑定的路线是更好的，因为b站上有大量的用(sovits/ddsp)-svc做AI翻唱的，听起来听感也不错。但是在把模型拉下来跑推理之后，我发现一个比较大的问题是，就算是质量更好的so-vits-svc，用GAN Generator生成出的音频电音比较严重[todo:audio]。我又换了好多个checkpoint，其中还有OpenCpop这种有一个人大量高质量干音数据集训练的，但是结果的电音都是相对比较严重的。

通过进一步阅读readme，了解到shallow diffusion model可能可以缓解电音问题。其具体工作方式是：
- 训练的时候，使用目标歌手的GT音频，通过加一个浅噪声，并且预测噪声，来学习[noisy mel -> clean mel]之间的分布transport；
- 推理的时候，对GAN Generator生成的音频添加对应的噪声，然后再用shallow diffusion模型denoise，期望降低电音。
但是初看这个方案就有一个很明显的训推不一致问题：
- 训练的时候使用的是GT音频；
- 推理的时候却期望对GAN生成的音频起作用。
实际跑完训练推理后，听感是diffusion带来了咬字不清的问题：在所有的辅音音节上，原本GAN输出的音频咬字比较清晰的，经过Diffusion之后就变得相当模糊，以至于让人经常听不清这一句唱了什么。

== 补丁

由于我是先意识到训推不一致再听到辅音咬字不清的，因此我就下意识认为这个问题是和训推不一致有关的（现在我又再次无法确定这个问题是什么导致的了，希望有一天我能有空把这个问题捡起来研究清楚）。

基于[训推不一致]这个问题，我想找的解决方法至少需要满足以下条件：
- 训推一致：训练输入是GAN的输出音频；训练的GT是数据集的高质量干音；
- 充分利用已有checkpoint（由于so-vits-svc的底模训练包含了很多虚拟主播的授权数据集而我无法获取，因此我希望可以把训练好的权重以一个比较高的利用率转换到新的模型上）
因此，上述离散时间步的Diffusion model肯定没有办法用了，因为我们没有从GAN生成的noisy mel到GT mel的完整加噪路径的，因此获取每个训练step的训练数据对(noisy mel, noise)。

但是一个补丁正好就可以打在这个点上：基于Rectified flow的Flow Matching正好不需要整个加噪路径，其只需要采样一个时间t，并按照这个时间在noisy和GT之间插值，就可以作为训练对。使用(加噪的声音，GT)作为配对就可以直接训练。
- 基于这种训练方式，我们自然地达成了训推一致；
- 将GAN输出的信号视为信号，高斯噪声视为噪声，通过一种匹配SNR的方式，我们可以将shallow diffusion model以一种数学上合理的方式转为flow matching的模型。
  - 对于So-vits-svc来说，我的数据是充足的，因为有底模的存在和“权重=说话人”的机制，单说话人两三个小时的数据就足够了。

*推导*

目标：将 Shallow Diffusion 在第 $K$ 个扩散步得到的加噪 GAN mel 映射到Flow Matching 的全局时间轴 $t in [0,1]$上的中间时刻 $t_K >0$.

设 $y$ 为GT mel，$s$ 为相同条件下GAN生成的mel，$K$ 表示shallow diffusion的加噪步数。定义：
#let akb = $overline(alpha)_K$
$
  a_K & =sqrt(akb), b_K =sqrt(1-akb), epsilon in N(0, II)
$

原 Shallow Diffusion 在第 $K$ 个扩散步得到的状态为

$
  q_K (s)=a_K s + b_k epsilon
$

采用rectified flow坐标：
$
  x_t = (1-t) x_"src" +t y, t in [0,1]
$

线性flow matching路径中，source 分量与 target 分量的系数分别为 $1-t$ 和 $t$，其对应的SNR(signao-to-noise ratio)和Shallow Diffusion 在第 $K$ 个diffusion step的 SNR相等：
$
         "SNR"_"FM" (K) & = t^2/(1-t)^2 \
  "SNR"_"diffusion" (K) & =akb/(1-akb)=a_K^2/b_K^2
$

由于 $t_K, a_K, b_K$ 均为正数，有
$
  t/(1-t)=a_K/b_K arrow.double.r t_K=a_K/(a_K+b_K)
$

但是仅匹配 SNR 还不足以使 diffusion 状态直接成为线性flow matching状态，因为 $q_K (s)$ 中两个系数之和通常不等于1。因此定义归一化后的入口状态
$
  z_K =q_K (s)/(a_K + b_K)
$

代入 $q_K (s)=a_K s + b_k epsilon$ 并利用 $t_K=a_K+b_K$：
$
  z_K & = a_K/(a_K + b_K) s + b_k/(a_K + b_K) epsilon \
      & = t_K s + (1-t_K) epsilon
$

因此， $z_K$ 精确对应线性flow matching的 $t$ 轴上的 $t_K$ 噪声强度。它不仅与diffusion step $K$ 具有相同的SNR，而且信号与噪声的绝对系数也与线性flow matching坐标一致。训练和推理的起始状态均取为
$
  x_t_K = z_K
$

在采样路径上还有更多推导以将flow matching匹配于原diffusion model，这里就不展开了。

*效果*
- 和理论相符，可以将预训练的shallow diffusion底模应用于flow matching，初始的loss就比较低，而且简单训练几十分钟就可以让flow matching输出reasonable的结果，说明这个迁移是在生效的
- 遗憾的是，经过A/B盲测，咬字比shallow diffusion只能说是略好，并没有解决部分字咬字不清的问题，因此被迫转向下一个方案

== Zero-shot SVC

Zero-shot这个方向就能找到近至四五个月之前的很前沿的开源工作。经过多个例子的试听，我感觉Yingmusic-SVC的效果是最好的，而且尤其是如果参考timbre的音频质量足够好（没有过载的干音直出），输出的音频效果是很不错的。但是其仍然存在几个比较严重的问题：
+ 断音。听感上一个长音中间会出现一至多个“断裂”，可以从mel-spectrogram里面看出来；
+ aliasing（这里似乎翻译成伪影更合适？）：从听感上来说，就是声音有的部分的谐波和基频好像在两个图层。

=== 改造

对于这个任务，我实际上是极其缺数据的，我手上只有60h左右的包括开源和自己b站爬的干净干音数据。基于此，经过一系列调研，尝试了以下方案：
+ 更换vocoder
  - 在试听vocoder在歌声任务的大横评之后，发现其实BigVGAN的表现极其一般且已被各种新的SOTA超过，会出现和我前面听到的类似的aliasing，怀疑是BigVGAN引入的；
  - 效果：换成SOTA的Pupu-Vocoder之后有明显改善，aliasing的问题几乎被完全解决。
+ 部分层添加conv模块，并且进行微调
  - 考虑整个网络目前只有attention，没有能显式建模局部连续性的模块
  - 实际上没啥用，也可能是数据太少，但是后来一想觉得数据量多了也没啥用，transformer里面已经加了RoPE了应当能辨识位置信息
+ 换成使用带有explicit f0输入的vocoder（PC-NSF-HiFiGAN）
  - 断音的地方从Mel-spectrogram可以看到能量偏移了f0，考虑可能引入explicit f0可以在mel->waveform的步骤缓解这个问题
  - 需要微调主模型，因为PC-NSF-HiFiGAN使用的mel-spectrogram的配置和原本的BigVGAN相同
  - 用我有限的数据进行微调之后效果不尽如人意，比较嘶哑；
  - 这个方案还有其他变体：
    + 给当前SOTA的Vocoder添加上explicit f0输入，但是这个也需要重新训练Vocoder；
    + 训练一个mel格式转换的模型，从pseudo-inverse开始迭代，训练一个将BigVGAN格式的Mel转换成HiFiGAN格式的Mel。
  - 上述方案都给出了可以辨识雏形的声音结果，但是各种细节都很不尽人意。我初步判断是数据量不足的的问题，于是许多问题又回到了去哪找数据......
+ 一种免训练的方案：
  + 先试用Pupu-Vocoder合成波形
  + 然后提取HiFiGAN格式的Mel，再使用PC-NSF-HiFiGAN使用explicit f0 condition重新合成。
  经过实验，这种方法是效果最好的，断音数量大幅减少，而且由于Pupu-Vocoder的参数量非常大，导致实际上二次分析的音频质量和PC-NSF-HiFiGAN的生成质量没有可以感知的差别。

最终敲定了方案4，并让AI将所有模型的推理移植到了Metal平台，并使用Rust实现以避免对Python的依赖。最终架构如图所示：

#image("./pipeline.png")

== 推理 & UI

由于我需要在Mac电脑上使用，推理仍然是使用一个我自己写的skill（可以在#link("https://prompts.petals.top/", "这里")找到）让Agent将PyTorch代码移植到mlx，并且使用Rust以避免Python环境管理的混乱。

虽说LLM Agent的出现让写UI的成本确实低了非常多，但是如果UI出bug了，要去调整UI的细节还是一件非常痛苦的事情，尤其是我这种不是专业客户端开发的，甚至有时候连_把问题用专业术语描述清楚_都比较难做到。基于我在开发#link("https://blog.petals.top/learn/2026-05-10-shift-as-restore/", "这个音高调节工具")和#link("https://blog.petals.top/learn/2025-05-20-snapviewer/", "这个显存分析可视化工具")的时候的比较痛苦的经历，我决定还是回归web技术栈，使用electron。

用了web技术栈就方便多了！你只需要一个前端艺术素养比较好的模型#footnote[比如：Claude Fable5, Kimi K3；我使用的是Kimi K3。As of 2026.08, *DO NOT USE GPT!!!*]，然后告诉他你想要复刻哪个软件的UI设计风格就可以了。我这里想要简约一点，就直接复刻VS Code的设计风格，然后Agent就自动生成出了app：
#image("./ui.png")

这次UI部分的工作比之前都舒服太多了，在比electron更好的方案出现之前我应该没有兴趣再使用各种原生方案了。

== Misc

=== Source-Filter理论、NSF架构

后来查阅资料后发现，BigVGAN的不足很可能是没有使用NSF的架构，而Pupu-Vocoder和PC-NSF-HiFiGAN都使用了这个架构。试听了大量vocoder的横评之后我认为这个猜想是合理的。
- source-filter理论指出，人的声音是由source部分和filter部分组成，source部分产生基频震荡和多级谐波，然后这个信号被输入filter被，由filter对声源进行共振塑形。
- NSF将这个理论应用于架构上，explicit地分离出source和filter并且用NN建模这两个组件。
- 这其实相当于对网络架构加上了额外的inductive bias。虽然现在大家每天都在强调 #link("http://www.incompleteideas.net/IncIdeas/BitterLesson.html", "the bitter lesson")，但是由于歌声领域的数据是严重不足的#footnote[绝大多数流媒体平台的歌声都是被以混音的形式放出，无法用于训练；而能用于训练的高质量数据是干音，这是需要在安静的家中或者录音棚，用一个音质至少良好的麦克风进行录制的。同时，雇人录制/获取干音也有一定人力成本，而由于没有明确的收益，没有什么实验室/公司有动力去做这件事。]，如果一个inductive bias能够显著加速模型学习，或者改善模型在少数据训练下的输出质量（比如这里，对于一个长音保持f0的稳定），是应该积极采用的。
