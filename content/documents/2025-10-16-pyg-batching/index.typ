#import "/config.typ": template, tufted
#show: template.with(
  title: "PyG Batching",
  description: "PyTorch Geometric Batching 机制详解",
  date: datetime(year: 2025, month: 10, day: 16),
)

= PyG Batching

内容来自#link("https://pytorch-geometric.readthedocs.io/en/latest/advanced/batching.html")[官方文档].

== 高级 Mini-Batching

创建 mini-batching 对于让深度学习模型的训练扩展到海量数据至关重要。

由于图是一种最通用的数据结构，可以包含任意数量的节点或边，因此传统的 padding 方法要么不可行，要么导致大量不必要的内存消耗。

在 PyG 中，adjacency matrices 以对角线方式堆叠，节点和目标特征简单地沿节点维度进行拼接：

$ A = mat(A_1, , ; , dots.down, ; , , A_n), quad X = mat(X_1; dots.v; X_n) $

== PyG DataLoader

PyG 借助 `torch_geometric.loader.DataLoader` 类自动将多个图 batch 成一个巨大的图。

`DataLoader` 会自动将 `edge_index` tensor 增加到当前处理图之前已聚合的所有图的累积节点数。

=== 图对（Pairs of Graphs）

```python
class PairData(Data):
    def __inc__(self, key, value, *args, kwargs):
        if key == 'edge_index_s':
            return self.x_s.size(0)
        if key == 'edge_index_t':
            return self.x_t.size(0)
        return super().__inc__(key, value, *args, kwargs)
```

=== 二分图（Bipartite Graphs）

```python
class BipartiteData(Data):
    def __inc__(self, key, value, *args, kwargs):
        if key == 'edge_index':
            return torch.tensor([[self.x_s.size(0)], [self.x_t.size(0)]])
        return super().__inc__(key, value, *args, kwargs)
```

=== 沿新维度进行 Batching

```python
def __cat_dim__(self, key, value, *args, kwargs):
    if key == 'foo':
        return None
    return super().__cat_dim__(key, value, *args, kwargs)
```
