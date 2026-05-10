#import "/config.typ": template, tufted
#show: template.with(
  title: "不通过反转正向传播的方式计算sinkhorn迭代的梯度",
  date: datetime(year: 2026, month: 1, day: 5),
)

#let diag = math.op("diag")
#let pdv(y, x) = $(diff #y) / (diff #x)$

== 问题设定

=== 问题

1. 输入矩阵: $X in RR^(n times n)$。
2. $P = exp(X)$（element-wise）。
3. 通过对 $P$ 进行 Sinkhorn-knopp迭代，得到bistochastic matrix $R = diag(alpha) P diag(beta)$。
4. 损失函数: $L = f(R)$，令 $G = nabla_R L$ 为已知梯度。

=== 目标

$L$ 对 $X$ 的梯度：$pdv(L, X)$。

=== TLDR

通过使用CG方法求解下列方程：

$ mat(I, R; R^T, I) mat(u; v) = mat((G dot.circle R) 1; (G dot.circle R)^T 1) $

可以得到 $L$ 对 $X$ 的梯度：

$ nabla_X L = (G - u 1^T - 1 v^T) dot.circle R $

== 求解

=== 求解线性系统

将上述方程改写成矩阵形式：

$ mat(I, R; R^T, I) mat(u; v) = mat((G dot.circle R) 1; (G dot.circle R)^T 1) = b_0 $

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
$ nabla_X L = (G - M) dot.circle R $

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

> 代码开源于#link("https://github.com/Da1sypetals/sinkhorn-bwd-cg")[Github]
