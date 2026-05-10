#import "/config.typ": template, tufted
#show: template.with(
  title: "DeepSeek mHC的简单演示",
  description: "Manifold Constrained Hyper-Connection 简单实现",
  date: datetime(year: 2026, month: 1, day: 4),
)

= DeepSeek mHC的简单演示（可能有错误）

DeepSeek发布了最新的魔改版Residual Connection：Manifold Constrained Hyper-Connection.

== 思路

1. 其基本思路是把旁路residual限制在某个集合上
   - 文中用更"几何"的manifold一词表述;
   - 退化的例子就是Kaiming的原版Residual Connection，约束是`residual = x`
   - 本文则将residual projection matrix的谱范数限制在 $<= 1$

2. 类似的思路还可以在比如物理模拟中看到：
   - 通过将物体的 transformation matrix 约束在 $S E (3)$，禁止物体形变，从而模拟刚体。

3. HC的基本思路应该是：
   - 原本就有n个stream
   - 在主线forward的时候，把n个stream合并为一个（pre-proj），通过这一层网络（$f$），然后再打散回n个stream（post-proj）
   - 支线复制输入x，通过一个res-proj进行信息混合之后，加回主线的输出

4. mHC对这个res-proj进行约束：
   - 要求其为bistochastic matrix.
   - 具体做法就是通过 sinkhorn 迭代直接将其映射到最接近的 doubly stochastic matrix 上。

== 简单实现(不含优化)

一种可能有错误的简单的代码实现#link("https://gist.github.com/Da1sypetals/0a7f70bf6b4ca7d46f0a1c5910e1a8b6")[在这里]如下.

```py
import torch
import torch.nn as nn
import torch.nn.functional as F
import einops as ein

N_ITER = 20

def sinkhorn_knopp(mat: torch.Tensor) -> torch.Tensor:
    for _ in range(N_ITER):
        mat = mat / mat.sum(-2, keepdim=True)
        mat = mat / mat.sum(-1, keepdim=True)
    return mat

n = 4  # stream width
C = 256  # embedding dim

norm = nn.RMSNorm((n * C,))

phi_pre = nn.Parameter(torch.randn(n * C, n))
phi_post = nn.Parameter(torch.randn(n * C, n))
phi_res = nn.Parameter(torch.randn(n * C, n * n))

def broadcast_to_n_stream(xl: torch.Tensor) -> torch.Tensor:
    return ein.repeat(xl, "... C -> ... n C", n=n)

def reduce_to_one_stream(xl: torch.Tensor) -> torch.Tensor:
    return ein.reduce(xl, "... n C -> ... C", "mean")

def manifold_constrained_hyperconnection(xl: torch.Tensor, layer: nn.Module) -> torch.Tensor:
    xl_vec = ein.rearrange(xl, "... n C -> ... (n C)")
    xl_vec_prime = norm(xl_vec)

    h_tilde_pre = alpha_pre * (xl_vec_prime @ phi_pre) + b_pre
    h_tilde_post = alpha_post * (xl_vec_prime @ phi_post) + b_post
    h_tilde_res = alpha_res * ein.rearrange((xl_vec_prime @ phi_res), "... (m n) -> ... m n", n=n) + b_res

    h_pre = F.sigmoid(h_tilde_pre)
    h_post = 2 * F.sigmoid(h_tilde_post)
    h_res = sinkhorn_knopp(h_tilde_res.exp())

    residual = ein.einsum(h_res, xl, "... m n, ... n C -> ... m C")

    x_pre = ein.einsum(h_pre, xl, "... n, ... n C -> ... C")
    layer_out = layer(x_pre)
    x_post = ein.einsum(h_post, layer_out, "... n, ... C -> ... n C")

    out = x_post + residual
    return out
```
