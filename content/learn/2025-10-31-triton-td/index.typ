#import "/config.typ": template, tufted
#show: template.with(
  title: "Triton Tensor Descriptor: 茴字的第三种写法",
  date: datetime(year: 2025, month: 10, day: 31),
)

今天我们来介绍 Triton 中的第三种进行 tensor 指针运算的 API：Tensor Descriptor。内容来自#link("https://triton-lang.org/main/python-api/generated/triton.language.make_tensor_descriptor.html")[triton 文档]。

== 关于 triton 的基本概念

- triton 只是和 python 共用语言前端，triton 会接管 python 的 AST
- 在第一次执行一个 kernel 之前发生的事情称为编译期，之后的执行称为运行时
- triton的 kernel launch 的grid 参数是一个 ndrange

== Tensor Descriptor的用法

=== 创建

```python
desc = tl.make_tensor_descriptor(
    pointer,
    shape=[M, N],
    strides=[N, 1],
    block_shape=[M_BLOCK, N_BLOCK],
)
```

其中：
- `pointer` 就是传入triton kernel的tensor
- `shape` 是一个整数列表，*可以编译期确定，也可以运行时动态传入*
- `strides` 是一个整数列表，*可以编译期确定，也可以运行时动态传入*
- `block_shape` 是一个整数列表，*必须是编译期常量*

=== 读写

==== 读
```python
value = desc.load([moffset, noffset])
```

==== 写
```python
desc.store([moffset, noffset], tl.abs(value))
```

== 例子

=== 例1

```python
@triton.jit
def inplace_abs(in_out_ptr, M, N, M_BLOCK: tl.constexpr, N_BLOCK: tl.constexpr):
    desc = tl.make_tensor_descriptor(
        in_out_ptr,
        shape=[M, N],
        strides=[N, 1],
        block_shape=[M_BLOCK, N_BLOCK],
    )

    moffset = tl.program_id(0) * M_BLOCK
    noffset = tl.program_id(1) * N_BLOCK

    value = desc.load([moffset, noffset])
    desc.store([moffset, noffset], tl.abs(value))


M, N = 256, 256
x = torch.randn(M, N, device="cuda")
M_BLOCK, N_BLOCK = 32, 32
grid = (M / M_BLOCK, N / N_BLOCK)
inplace_abs[grid](x, M, N, M_BLOCK, N_BLOCK)
```

=== 例2：Flash Attention

#link("https://github.com/Da1sypetals/Triton-TD-Examples/blob/main/attention/td_flash.py")[Flash Attention with Tensor Descriptor]
