#import "/book.typ": book-page
#show: book-page.with(title: "XMM")

= Conjugate Gradient

#set heading(numbering: "1.")

#let aminx = $limits("argmin")_x$
注意，本文没有任何数学推导。我们从直观上理解这个算法，然后直接介绍算法的流程。希望了解数学推导的读者可以查看#link("https://www.cs.cmu.edu/~quake-papers/painless-conjugate-gradient.pdf", "CMU的教案")及其#link("https://flat2010.github.io/2018/10/26/%E5%85%B1%E8%BD%AD%E6%A2%AF%E5%BA%A6%E6%B3%95%E9%80%9A%E4%BF%97%E8%AE%B2%E4%B9%89/#8-%E5%85%B1%E8%BD%AD%E6%A2%AF%E5%BA%A6%E6%B3%95", "翻译")。
= 问题
$
  A x=b
$
或者，等价的，
$
   aminx f(x)
$
其中
$
  f(x) = 1/2 x^T A x - b^T x
$

= 预备知识
== 从高中学的二级结论说起 <ejjl>

高中的时候我们学过椭圆：
$
  a^(-2)x^2+b^(-2)y^2=1
$
如果你记性好的话，你应该记得这个二级结论：
#image("../../assets/cg/sol.jpg", width: 70%)
这是一个从圆里面推广而来的结论；如果$a=b$，椭圆退化为圆，$k_(O M) k_l=-1$，即 $O M, l$ 两条直线垂直。

== 最速下降法
首先，你应该知道梯度下降法：
$
  x_(i+1)=x_i+-alpha nabla f(x_i)
$
最速下降法就是在梯度下降法的基础上，选择$alpha$使得$x_(i+1)$达到最小（在搜索方向上的最小值）：
$
  alpha^*= limits("argmin")_alpha f(x_i+-alpha nabla f(x_i))
$

= 共轭梯度法

== 记号
- $x_i$：第 $i$ 次循环之后的 $x$ 向量
- $r_i$：$b_i-A x_i$ ，目标函数$f(x)$在$x_i$点的*负*梯度，或者线性方程组在$x_i$点的残差。
  - 请记住 *负梯度和残差是一个东西！*
- $d_i$：在 $x_i$ 点的搜索方向。最速下降算法里$d_i=r_i$，共轭梯度里面需要一点修正。
== 最速下降

+ 最速下降的新方向：$r_(i+1)$
  - 新方向与前一步下降方向 $r_i$ 垂直（画个等高线图直观理解，或者回想一下“等势面和电场线垂直”）
  #image("../../assets/cg/grad.jpg", width: 60%)

+ 最速下降的 $alpha$
$
  alpha_i=(r_i^T r_i)/(d_i^T A d_i)
$
== 共轭梯度
我们直接逐项类比最速下降。
- 新方向与前一步下降方向 $r_i$ #strike[垂直] 斜率之积为 $-a^(-2) b^2$ (@ejjl)
  - 这个方向由最速下降的方向进行一些小改动得到，我们可以在后面的算法部分(@algo)看到。
  #image("../../assets/cg/cggrad.jpg", width: 75%)
- 步长 $alpha$：由于是在一条直线上做优化，因此和最速下降的 $alpha$ 相同。
由于一次迭代只涉及到两个点、两个向量，只能构成一个平面，我们甚至不需要将二维向多维推广。 

== 算法 <algo>
=== 初始化
算法输入：$A, b, x_0$
#image("../../assets/cg/algo-init.jpg", width: 35%)
=== 算法过程
#image("../../assets/cg/algo.jpg", width: 35%)
其中的最后一步就是通过 $beta$ 将 $r_(i+1)$ 修正成 $d_(i+1)$ 的。
=== 起讫
+ *起*：如果你对解 $x$ 有粗略的估计，就使用那个值作为起始点 $x_0$；否则，直接使用 $x_0=0$.

+ *讫*：通常的做法是在残差向量的2-norm小于某个给定阈值的时候就停下来。通常这个阈值为初始残差的一小部分 
  $
    ||r_i|| < epsilon ||r_0||
  $
  其中 $epsilon$ 是一个输入的参数。

== 杂项
+ 由于 $A d_i$ 在每个循环中都要被计算，且
  $
  r_(i+1)=r_i-alpha_i A d_i
  $
  故可以用上式计算 $r_(i+1)$，而不必用 $b-A x_(i+1)$.
+ 上述方法有浮点误差累计的危险，因此我们应该每过几个循环就重新用 $r_i=b-A x_i$ 重新计算残差。

= Preprocessor
TODO