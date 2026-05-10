#import "/config.typ": template, tufted
#show: template.with(
  title: "cuTile 历险记，第1集：编译",
  description: "cuTile 编译流程探索",
  date: datetime(year: 2025, month: 12, day: 6),
)

= cuTile 历险记，第1集：编译

原本第一集应该是语法和随便找个bmm，flash-attn2的kernel来实现一下并且进行benchmark的，因为所以gpu编程博客都是这样的。

*Disclaimer: 我不了解编译器，以下所有内容基于自己的理解，和编译器术语出现偏差乃至出错之处敬请指出*

nv官网提示我们，需要cuda driver一个较高的版本，cuda toolkit 13.1（tileiras汇编器），以及blackwell以上的GPU（目前）才能使用cutile。但是我没有b200或者50系（cc12）的游戏卡，我手上能碰到的机器刚好截至hopper，所以我并没有办法编译执行cutile程序，失去了尝鲜的机会。

但是有了cutile-python这个python端，下降到mlir之前的中间代码还是可以了解一下的。

== 探索过程

=== 屏蔽C库

我们发现报错发生在 `src/cuda/tile/_cext.pyi`，提示驱动版本过低。vibe coding 启动，我们让 LLM 把 `_cext` 这个 cpp 库用一个 mock 进行替代，骗过编译器；然后包装了一个 CutileIrDump 类，通过 `cuda.tile._compile._get_final_ir` 函数可以获取到 cuTile IR。

#figure(image("cutileir.png"))

了解编译流程，我们主要从 `_get_final_ir` 入手。

```python
def _get_final_ir(pyfunc, args, tile_context) -> ir.Function:
    ir_ctx = ir.IRContext()
    func_ir: ir.Function = get_function_ir(pyfunc, ir_ctx, call_site=None)
    ir_args = func_ir.bind_arguments(args, get_constant_annotations(pyfunc))
    func_ir = infer_types_pass(func_ir, ir_args, pyfunc, tile_context)
    # -------- 上方：语法、类型检查 ----------
    # -------- 下方：（部分）机器无关优化 ----------
    eliminate_assign_ops(func_ir)
    dead_code_elimination_pass(func_ir)

    if not CUDA_TILE_TESTING_DISABLE_TOKEN_ORDER:
        alias_result = alias_analysis_pass(func_ir)
        token_order_pass(func_ir, alias_result)

    rewrite_patterns(func_ir)
    hoist_loop_invariants(func_ir)
    split_loops(func_ir.root_block)
    dead_code_elimination_pass(func_ir)
    return func_ir
```

大概看一下代码：

- `get_function_ir` 将 Python 函数转换为第一层中间表示
- `bind_arguments` 将实际参数绑定到函数的形式参数
- `infer_types_pass` 类型推断与常量传播

=== 类型（tile metadata）

可以从函数名称猜到在分割线之前的部分，都是语法、类型检查，在分割线之后的部分，是机器无关的优化。于是猜测，如果需要获取 tile 的 metadata，最接近源代码的位置可能就是 `infer_types_pass` 的返回值了。

在此处打上断点，进行分析：
#figure(image("cutile-debug-0.png"))

可以看到 `func_ir.root_block._operations` 里面就是我们代码经过最基本的翻译，并经过 shape 检查之后形成的中间表示。

以下列这个 kernel 为例，

```python
import cuda.tile as ct
ConstInt = ct.Constant[int]
PAD_ZERO = ct.PaddingMode.ZERO

def zfunc(a, b):
    sum = a + b
    res = ct.cos(sum)
    return res

def apply_mod(mod, c_tile, i_m, i_n, tm, tn):
    mod_tile = ct.load(mod, index=(i_m, i_n), shape=(tm, tn), padding_mode=PAD_ZERO)
    zval = zfunc(mod_tile, c_tile)
    return ct.sin(zval)

@ct.kernel
def my_kernel(a, b, c, mod, tm: ConstInt, tn: ConstInt, tk: ConstInt):
    i_m = ct.bid(0)
    i_n = ct.bid(1)
    acc = ct.zeros((tm, tn), dtype=ct.float32)

    for i_k in range(tk):
        t_a = ct.load(a, index=(i_m, i_k), shape=(tm, tk), padding_mode=PAD_ZERO)
        t_b = ct.load(b, index=(i_k, i_n), shape=(tk, tn), padding_mode=PAD_ZERO)
        acc = ct.mma(t_a, t_b, acc)

    tile1 = ct.full((32, 16), 0.0, ct.float32)
    tile2 = ct.full((32, 16), 0.0, ct.float32)
    tile3 = zfunc(tile1, tile2)

    tile4 = ct.full((16, 64), 2.0, ct.bfloat16)
    tile5 = ct.full((16, 64), 2.0, ct.bfloat16)
    tile6 = zfunc(tile4, tile5)

    c_tile = apply_mod(mod, acc, i_m, i_n, tm, tn).astype(ct.float16)
    ct.store(c, index=(i_m, i_n), tile=c_tile)
```

截取一小段中间表示的文本形式，可以看到比如 tile4 和 tile5 的 dtype 和 shape 都已经确定了。

#figure(image("py-cutile-ir.png"))

=== cuTile Python Bytecode 和后续

如果直接获取 `_get_final_ir` 函数的输出并且调用 `to_string()`，就会得到 cuTile Python IR。因为已经执行过了一些简单的优化，所以原始代码中的变量名信息已经丢失掉了。

在 `src/cuda/tile/_compile.py` 的 `compile_tile` 函数中，可以看到这种代码会先转换为 cuTile Python Bytecode，然后被 C++ 扩展库编译为 TileIR，最后调用黑箱 `tileiras` 编译成 cubin。

#figure(image("compile-bytecode.png"))

*因为我没有能力往下分析，且我没有老黄最新的卡，所以后续略。*
