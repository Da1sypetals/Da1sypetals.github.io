#import "/book.typ": book-page
#show: book-page.with(title: "XMM")

= Conjugate Gradient

#set heading(numbering: "1.")

#let aminx = $limits("argmin")_x$

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
  f(x) = 1/2 x^T A x - b x
$

= 预备知识
== 从高中学的二级结论说起 <ejjl>

高中的时候我们学过椭圆：
$
  a^(-2)x^2+b^(-2)y^2=1
$
如果你记性好的话，你应该记得这个二级结论：
#image("../../assets/cg/sol.png", width: 70%)
这是一个从圆里面推广而来的结论；如果$a=b$，椭圆退化为圆，$k_(P A)k_(P B)=-1$，即$P A, P B$ 两条直线垂直。

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
- $d_i$：在 $x_i$ 点的搜索方向。最速下降算法里$d_i=r_i$，共轭梯度里面需要一点修正。
== 最速下降

+ 最速下降的新方向：$r_(i+1)$
  - 新方向与前一步下降方向 $r_i$ 垂直（画个等高线图直观理解，或者回想一下“等势面和电场线垂直”）
  #image("../../assets/cg/grad.png", width: 60%)

+ 最速下降的 $alpha$
$
  alpha_i=(r_i^T r_i)/(d_i^T A d_i)
$
== 共轭梯度
=== 方向、步长
我们直接逐项类比最速下降。
- 新方向与前一步下降方向 $r_i$ #strike[垂直] 斜率之积为 $-a^(-2) b^2$ (@ejjl)
- 步长 $alpha$：由于是在一条直线上做优化，因此和最速下降的 $alpha$ 相同。
由于一次迭代只涉及到两个点、两个向量，只能构成一个平面，我们甚至不需要将二维向多维推广。 
=== 算法
