#import "/config.typ": template, tufted
#show: template.with(
  title: "Shift as Restore, Ep. 3: Flow Matching + BERT",
  date: datetime(year: 2026, month: 5, day: 21),
)

== 思路

前几次实验的输入都只是经过DSP的脏音频，因此输出和脏音频是更加贴近的。因此我认为需要改进学习的范式需要输入干净的音频作为参考。

想到的是两种想法，一种是把另一段干净音频用cross attention的形式给需要去噪的音频进行参考。另一种形式是直接把相邻的干净音频放在上下文窗口之内直接用Self Attention进行参考。

由于前一种方法，每一条音频还需要去找相应的配对音频用作参考，在训练和推理的时候，构造数据都是一个问题，因此我认为后一种想法的实现会更自然一些，于是就选择了后一种方法。

== Representation

根据前几次实验的经验，幅度和相位是需要分开建模的，否则很容易出现正确的方向是改变相位，但是幅度被隐式的惩罚了，导致模型学会了让幅度归零等local minima。

STFT谱是 $F="STFT点数"/2 + 1$ 个复数，每个复数是 $z=A exp("j"phi)$。

Phase Wrapping: 实际上 $-pi + epsilon$ 和 $pi - epsilon$ 只差了 $2 epsilon$，但是由于相位的值域的问题，会导致实际的数值差了 $2pi-2epsilon$，因此 $phi$ 直接做神经网络的输入输出是不好的选择，我们这里选择使用相位的两个三角函数值 $cos phi, sin phi$ 来唯一定位 $(-pi, pi]$ 之间的一个角度，这样，相位上加一个小量，反映到这两个三角函数值上仍是一个小量。

为了使得输出的两个值分别代表 cos 和 sin，训练和推理分别需要一些trick：
- 训练：将这两个值的平方和为 1 作为一个loss进行约束；
- 推理：对于推理的输出，取 $phi="atan2"(y, x)$.

这样一个复数就被建模为三个浮点数 $(A, cos phi, sin phi)$，一段 $N$ 帧的音频就被转为 $(N, F, 3)$ 的Tensor。

== BERT, Masked Sequence Modeling

=== 思路


#figure(image("bert.png", width: 70%))

=== 输入通道

对于Unmasked的帧，输入包含
- 原始音频
- 0, 由于没有Flow Matching的状态，用0填充
- 0, 代表unmasked

对于masked的帧，输入包含
- artifact音频
- 当前Flow Matching的状态 $x_t$
- 1, 代表masked

=== 输出

对于每一个masked帧，输出 $F$ 个复数代表这一帧的STFT谱，每个复数是 $(hat(A), hat(x), hat(y))$.

== 网络结构

这是整个流程中最不重要的一部分。网络结构包含频率轴方向的Attention（同时用于token mixing和下采样），时间轴方向的的卷积（深度可分离卷积，同时用于token mixing和下采样）和Attention（用于深层的token mixing），通过adaptive layer norm注入积分步数 $t$ 的信息，其余细节略。我这个结构也是Claude帮我设计的；其实只要有时域和频域的token mixing，不管换什么网络应该都能训起来的。

== Loss

*Magnitude*: MSE, $L_A=(A-hat(A))^2$

*Phase*: Square of euclidean distance, $L_phi=(cos phi -hat(x))^2+(sin phi -hat(y))$

$L=L_A+L_phi$.

== 性能优化

=== 少步采样

实际上这是次要的...因为没有什么是比模型的性能更重要的了，如果效果好的话等十分钟也不是不能接受的。但是我们还是尝试优化一下。

*一步*采样是不可能做到的，这是因为后两个通道的输出 $(cos phi, sin phi)$ 在 $t=0$ 的时候速度总是指向原点，大小近似为模，因此第一步总是向原点，导致相位退化为近乎随机（在原点附近密集地分布）。

*少步*采样是可以做到的。经过实验，大致4到8步就可以提供较好的结果。在应用时我们默认执行10步采样，以获得更好的效果。


