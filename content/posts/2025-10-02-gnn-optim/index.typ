#import "/config.typ": template, tufted
#show: template.with(
  title: "近期GNN Attention算子优化工作速览",
  date: datetime(year: 2025, month: 10, day: 2),
)

注：本文用LLM辅助写作的地方主要在：*我认为LLM比我理解的更好的地方，会用LLM的表述代替。*

== 问题设定

需要计算Graph Transformer中的Attention。在此我们忽略multihead-attention，考虑基本的single-head attention.

此外，我们的attention mask(邻接矩阵A)是非结构化稀疏的。

=== Notation

```
n: 图节点数，规模为 1k~1M
nnz: 图边数（稀疏矩阵非零元素数）
q, k, v: (n, d)
A: (n, n), binary, 高度稀疏
```

=== 计算公式

```
softmax((q @ k.transpose()) * A) @ V
```

== 实现：naive version

1. 最简单的就是把A给materialize出来，然后用作attention_mask。问题是A是$n^2$的，显存不够用。
2. A用COO方式存储，大小(2,nnz)，然后先把每条边的qk-pair取出来得到(nnz,d)，然后再做reduce和scatter, 和V相乘。

== Reformulate

我们引入三个算子:

- **SDDMM (Sampled Dense-Dense MatMul)**
- **Sparse Softmax**: 在稀疏矩阵上按行softmax
- **SpMM**：sparse A @ dense B

此时我们的计算公式就可以重新写成:
```
out = SpMM(Softmax(SDDMM(Q, K_T, A)), V)
```

== 实现：DGL

#link("https://www.dgl.ai/dgl_docs/en/2.2.x/notebooks/sparse/graph_transformer.html")[Graph Transformer in a Nutshell]

```python
attn = dglsp.bsddmm(A, q, k.transpose(1, 0))
attn = attn.softmax()
out = dglsp.bspmm(attn, v)
```

算子在DGL库内部由CUDA实现。存在以下优化点：
- 进行的是最直观的并行，没有进行充分的优化
- 各个kernel分开执行，没有融合
- 没有利用tensor core

== 实现：FlashSparse

#link("https://github.com/ParCIS/FlashSparse/tree/main/eva")[FlashSparse]

主题：对SDDMM,SpMM进行优化；尝试在稀疏输入中以最小粒度利用tensor core。

基于一个基本观察：A × B = C ⟹ (Bᵀ × Aᵀ)ᵀ = C，发明了交换与转置MMA计算策略。

- **矩阵格式**：ME-BCRS格式

#figure(image("2025-10-02-19-50-28.png"))

== 实现：DF-GNN

#link("https://github.com/paoxiaode/DF-GNN")[DF-GNN]

主题：block/warp调度和算子融合

使用的矩阵格式是CSR，不需要做额外的格式转换。

在常用工作范围内，forward速度达到DGL实现的2.5x ~ 3x。

#figure(image("2025-10-02-19-50-59.png"))

== F3S

#link("https://github.com/HPCForge/Fused3S/tree/main/scripts")[F3S]

主题：算子融合+混合精度+利用tensor core

- 仅有forward的实现
- 使用了自定义的矩阵格式BSB

#figure(image("2025-10-02-19-52-13.png"))

速度达到DGL实现的3x(相对稀疏) 到5x (相对稠密）。
