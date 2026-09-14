#import "/config.typ": template, tufted
#show: template.with(
  title: "设计一个可以控制音高的Vocoder",
  date: datetime(year: 2026, month: 9, day: 25),
)

_AI声明：本项目由Kimi K3，Devin SWE 2（研究讨论）和DeepSeek V4.1 Flash（运维）协助完成。其中Kimi K3通过Cursor调用，其基础设施提供商位于美国，不存在被路由到Claude等其他模型的可能性。_

== 简介

=== vocoder是什么
TODO

== Idea

=== 想法：对抗式移除$f_0$
#let df0 = $D_(f_0)$
#let f0 = $f_0$
#let fe = $F_e$
初步设想中，这个系统由两个模型组成：encoder和f0 discriminator。
- encoder模型负责从mel中提取出#f0 无关的features，以“让#df0 无法从features里面提取出任何 #f0 信息”为优化目标；
- f0 discriminator#df0 从这个features里面尝试提取#f0，以“从#fe 中提取出#f0”为目标来优化#df0 为优化目标。
通过这两个模型之间的对抗，达到让encoder features不含#f0 信息的目标。

=== 如何定义“无法提取出任何 #f0 信息”
#f0 是一个标量，所以最自然的方法是把检测f0定义为一个回归问题。但是现代#f0 检测模型（RMVPE，FCPE）都不约而同地把f0检测定义为一个分类问题：把人类发声的可能f0按照一个公差进行等差数列分桶，每一个桶就是一个类别。

对于我们的任务，有明确的理由应该选择后者，因为我们想要把“没有任何 #f0 信息”定义为一个数学上的目标，此时回归式的定义就不可用了：
- 一个单值输出无法表达“不确定性”或“无信息状态”。
- 例如，如果回归器输出 200 Hz，模型无法区分这是“非常确定当前音高就是 200 Hz，还是“完全没有线索，只能瞎猜一个平均音高 200 Hz。标量回归天然缺失了表示“熵（不确定度）”的自由度。
而“完全无信息”在概率分布上有良定义的最大熵形式：
- 在信息论中，“完全不知道 $f_0$ 是多少”对应的是最大熵分布（Maximum Entropy），即离散空间的均匀分布 $U=[1/K, 1/K, ..., 1/K]$。
- 这样，我们就可以将对抗目标设置为预测分布逼近均匀分布（最小化其与均匀分布的 KL 散度）。当预测分布达到均匀分布时，条件熵达到最大值 $H(f_0 | "feature") = log K$，特征与#f0 的互信息 $I("feature"; f_0) arrow.r 0$，数学定义明确且有界。

采纳分桶预测分布的方案后，可以把#f0 检测模块的输出定义为输出一个#f0 分桶上的离散分布，通过交叉熵损失优化#df0，通过和均匀分布$U$之间的KL散度优化encoder。

=== Idea验证：AutoEncoder

根据经验，Vocoder的训练是很慢的，如果直接在Vocoder上做实验会严重拖慢想法验证的速度。于是首先想到了进行一个如下AutoEncoder架构的小规模实验：

#image("./ae.png")

好处是：
- 在验证的时候通过一个足够好的vocoder对重建的Mel合成音频，可以直接通过听感验证f0是否残留，其他音色特征是否保留
- 重建有明确的GT也就是自己，而且容易观察f0 discriminator的loss等指标

以下是实验尝试回答的问题，每个实验都跑至少30k steps。
- *#f0 是否能被移除掉。*实验结果表明，#f0 在一定程度上被移除：
  - 对训练好的的encoder features重新训练一个新的 #df0 (而不是使用对抗训练的时候的那个)，检测出原f0的正确率在$5%~8%$，远低于RMVPE的$98%+$；
  - 并且decoder通过AdaLN-Zero注入的 #f0 也会以合理的方式注入到输出的音频中，听感上音频也是变调之后听起来合理的。
- *Muon优化器是否适用。*使用用Moonlight版本的Muon并match AdamW update RMS@kexuefm-11416，经过控制变量实验，Muon优化器在#df0 不适用，而应用于Encoder和Decoder部分虽然可以带来更加平滑的loss曲线，但是最终结果并没有可感知的提升（音频模型目前最可靠的评估方式还是用耳朵听...），因而弃用。
- *是否需要使用VAE式的KL Loss进行latent regularization。*经过实验，使用VAE代替AE ($beta in {10^(-4), 10^(-5), 10^(-6)}$)，效果没有得到提升，反而造成了更严重的电音。暂时怀疑是引入的$epsilon$所导致；虽然无法在vocoder架构下确认这一点，但是至少提供了_普通Autoencoder效果不会太差_的线索。

网络结构是一个ConvNeXt架构@convnext 的非压缩式Autoencoder；#df0 部分则是直接照抄了FCPE@fcpe 的模型架构。


== 端到端Vocoder

=== Source-Filter理论和NSF架构
// 整体设计
*Source-Filter理论*

由声学家 Gunnar Fant 在其经典著作@fant1960acoustic 中系统建立，该理论将复杂的语音发声机制解耦为两个线性无关的模块：
1. *Source模块*：
- *浊音（Voiced）*：声带周期性振动，产生包含基频 $f_0$ 及其谐波（Harmonics）的周期性脉冲序列或非线性气流脉冲。
- *清音/静音（Unvoiced）*：声门打开或形成狭窄通道，形成宽带非周期性气流湍流（近似白噪声）。

2. *Filter模块*：声道（咽腔、口腔、鼻腔等）具有特定的物理共振几何形态，扮演一个线性时变时域/频域滤波器。它在特定频率产生共振峰（Formants），增强或衰减声源中的特定频率分量，赋予语音音素、音色与语义特征。

数学上，语音生成信号 $S(omega)$ 可表示为声源频谱 $E(omega)$ 与声道频响函数 $V(omega)$ 的时域卷积/频域乘积：
$
  S(omega) = E(omega) dot V(omega)
$

*基于S-F理论的Neural Vocoder*

S-F理论过于简化的模型与严格的线性卷积限制限制了合成的音质。现代模型在继承了“Excitation与Filter显式解耦”思想的基础上，抛弃了理论中过于理想化的数学假设：

- Source模块加入了神经网络进行修正。以 hn-NSF 与 SiFi-GAN 为例，声源不再单纯依赖固定的人工三角脉冲或冲激串，而是引入了可微正弦谐波振荡器与时变加权噪声的组合，并且添加了可学习的神经网络模块。
- 不再限制Filter为纯线性因果数字滤波器，而是使用神经网络建模任何可能的声学函数，使得输出波形尽可能逼真。
- 与传统模型不同，Source和Filter*均*分别输入encoder features和#f0，两个网络的功能主要从网络架构的Inductive Bias和条件的注入方式进行区分。


=== Vocoder结构

架构基于前面的Autoencoder设计，主要改动是将Decoder换成S-F架构的Vocoder，并且加上波形生成的对抗Loss。
#image("./vocoder.png")
Filter网络架构和对抗Loss的设计主要来自Pupu-Vocoder@pupu；Source注入的方式主要来自#link("https://github.com/Coulin9", "Coulin9")的设计。此外，基于#link("https://github.com/Coulin9", "Coulin9")的实验，Vocoder以WORLD features作为condition输入是一个听感合理的baseline，因此设计中Encoder features先和WORLD features融合之后，再作为condition提供给Source和Filter。以下是模型定义的节选：

```python
class VocoderGenerator(nn.Module):
    def __init__(
        self,
        sample_rate: int = 44100,
        hop_size: int = 256,
        encoder_hidden: int = 384,
        encoder_blocks: int = 12,
        feature_dim: int = 256,
        condition_dim: int = 256,
        source_stage_channels: list[int] = (80, 80, 64, 48, 32),
        upsample_rates: list[int] = (4, 8, 2, 2, 2),
        upsample_initial_channel: int = 896,
    ):
        super().__init__()
        self.encoder = MelEncoder(hidden_dim=encoder_hidden, feature_dim=feature_dim, num_blocks=encoder_blocks)
        self.condition_mlp = ConditionalMLP(feature_dim + 144, 320, condition_dim)
        self.source = NHSourceNetwork(
            condition_channels=condition_dim,
            upsample_rates=list(upsample_rates),
            stage_channels=list(source_stage_channels),
            sample_rate=sample_rate,
            hop_size=hop_size,
        )
        self.filter = PupuFilter(
            condition_channels=condition_dim,
            upsample_initial_channel=upsample_initial_channel,
            upsample_rates=list(upsample_rates),
            source_channels=self.source.output_channels,
        )
```

=== 训练
TODO

=== 效果展示
TODO



#bibliography("ref.bib")
