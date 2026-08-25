#import "/config.typ": template, tufted
#show: template.with(
  title: "DeepSeek mHC的简单演示",
  date: datetime(year: 2026, month: 1, day: 4),
)

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


#let diag = math.op("diag")
#let pdv(y, x) = $(partial #y) / (partial #x)$

== 思考

是否可以不通过反转正向传播的方式计算sinkhorn迭代的梯度？

=== 问题

1. 输入矩阵: $X in RR^(n times n)$。
2. $P = exp(X)$（element-wise）。
3. 通过对 $P$ 进行 Sinkhorn-knopp迭代，得到bistochastic matrix $R = diag(alpha) P diag(beta)$。
4. 损失函数: $L = f(R)$，令 $G = nabla_R L$ 为已知梯度。

=== 目标

$L$ 对 $X$ 的梯度：$pdv(L, X)$。

=== TLDR

通过使用CG方法求解下列方程：

$ mat(I, R; R^T, I) mat(u; v) = mat((G dot.o R) 1; (G dot.o R)^T 1) $

可以得到 $L$ 对 $X$ 的梯度：

$ nabla_X L = (G - u 1^T - 1 v^T) dot.o R $

== 求解

=== 求解线性系统

将上述方程改写成矩阵形式：

$ mat(I, R; R^T, I) mat(u; v) = mat((G dot.o R) 1; (G dot.o R)^T 1) = b_0 $

=== 组装梯度

$ pdv(L, X_(i j)) = (G_(i j) - u_i - v_j) R_(i j) $

=== 性质

==== 1. 多解

考虑非零向量 $w = mat(1; -1)$。

根据bistochastic matrix性质 $R 1 = 1$ 和 $R^T 1 = 1$：

$ A w = mat(1 - 1; 1 - 1) = 0 $

由于存在非零向量在 $A$ 的零空间中，故 $det(A) = 0$。

==== 2. 不变量

虽然解 $x$ 包含不确定的偏移量 $k$，但我们的计算目标是确定的。

$ M = u 1^T + 1 v^T quad (M_(i j) = u_i + v_j) $

将通解代入：

$ M(k) = u_0 1^T + 1 v_0^T = M_"fixed" $

==== 3. 形式变换

从原系统消元:

$ (I - R^T R) v = s_c - R^T s_r $

其中 $S = I - R^T R$ 是对称半正定的。

== 算法

1. *准备右端项*
$ s_r = (G dot.o R) 1, quad s_c = (G dot.o R)^T 1 $

2. *构建半正定系统*
$ S = I - R^T R $
$ b = s_c - R^T s_r $

3. *用 CG 求解*
$ S tilde(v) = b $

4. *构造解*
$ u = s_r - R tilde(v) $
$ v = tilde(v) $

5. *组装结果*
$ M_(i j) = u_i + v_j $

6. *最终梯度*
$ nabla_X L = (G - M) dot.o R $

== PyTorch 实现

```python
import torch

def sinkhorn_forward(M, iters=20):
    P = torch.exp(M)
    R = P
    for _ in range(iters):
        R = R / R.sum(-2, keepdim=True)
        R = R / R.sum(-1, keepdim=True)
    return R, P

def batch_cg_solve_singular(A, b):
    batch_size, n, _ = A.shape
    x = torch.zeros_like(b)
    r = b.clone()
    p = r.clone()
    rs_old = torch.einsum("bi,bi->b", r, r)

    for i in range(n):
        Ap = torch.einsum("bij,bj->bi", A, p)
        pAp = torch.einsum("bi,bi->b", p, Ap)
        alpha = rs_old / (pAp + 1e-11)
        x += torch.einsum("b,bi->bi", alpha, p)
        r -= torch.einsum("b,bi->bi", alpha, Ap)
        rs_new = torch.einsum("bi,bi->b", r, r)
        beta = rs_new / (rs_old + 1e-11)
        p = r + torch.einsum("b,bi->bi", beta, p)
        rs_old = rs_new

    return x

def sinkhorn_backward_n_rank0(grad_R, R, cg_iters=10):
    R_detached = R.detach()
    G = grad_R

    r = (R_detached * G).sum(dim=-1)
    c = (R_detached * G).sum(dim=-2)

    R_T = torch.einsum("bij->bji", R_detached)
    RTR = torch.einsum("bij,bjk->bik", R_T, R_detached)
    eye = torch.eye(n, device=R.device, dtype=R.dtype).unsqueeze(0).expand(batch_size, -1, -1)

    S0 = eye - RTR
    b = c - torch.einsum("bij,bj->bi", R_T, r)

    v_tilde = batch_cg_solve_singular(S0, b)
    u = r - torch.einsum("bij,bj->bi", R_detached, v_tilde)
    v = v_tilde

    M = u.unsqueeze(-1) + v.unsqueeze(-2)
    grad_X = (G - M) * R_detached

    return grad_X
```


