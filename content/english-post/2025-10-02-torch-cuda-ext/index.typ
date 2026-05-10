#import "/config.typ": template, tufted
#show: template.with(
  title: "Notes on Writing PyTorch CUDA Extensions",
  description: "Practical notes on PyTorch CUDA extension development",
  date: datetime(year: 2025, month: 10, day: 2),
  lang: "en",
)

= Notes on Writing PyTorch CUDA Extensions

*Intro: PyTorch is a Deep Learning Operating System.*

== Check tensor storage

=== Device check

You should ALWAYS check EXPLICITLY whether input tensors are on desired devices. In most cases you want them on the same GPU.

**API:**
- `tensor.is_cuda()`
- `tensor.device()`

Sometimes the not-on-correct-device problem causes strange error messages like `Cusparse context initialization failure`.

=== Contiguity check

Most implementations assume row-major contiguous storage. You should explicitly check:

**API:** `tensor.is_contiguous()`

=== Cheatsheet

```cpp
void CheckInputTensors(const std::vector<torch::Tensor> &tensors) {
    TORCH_CHECK(!tensors.empty(), "No tensors provided");
    auto first_device = tensors[0].device();
    TORCH_CHECK(first_device.is_cuda(), "First tensor is not on CUDA");
    int idx = 0;
    for (const auto &tensor: tensors) {
        TORCH_CHECK(tensor.device() == first_device,
            "All tensors must be on the same CUDA device");
        TORCH_CHECK(tensor.is_contiguous(),
            "All tensors must be contiguous");
        idx += 1;
    }
}
```

== CUDA stream

Remember to always get the current CUDA stream via `at::cuda::getCurrentCUDAStream()` and pass it as the 4-th parameter in the kernel call.

This is especially important when your operator is used in distributed training.

== CUDA toolkit version problem

Most "symbol not found" problems are caused by compiler/assembler/library version mismatch.

- PyTorch has a CUDA version (VT) it was compiled on.
- Your system CUDA toolkit has version (VE).
- Make sure VT and VE perfectly match (NOT just major version match).

== Memory Management in PyTorch

When you need a buffer on HBM, your first instinct might be `cudaMalloc` and `cudaFree`. However, these force synchronization between CPU and GPU.

PyTorch manages VRAM internally with a pooling and caching mechanism.

Using the PyTorch allocator:
```cpp
auto buffer_options = torch::TensorOptions().device(your_device).dtype(torch::kInt8);
auto buffer_tensor = torch::empty({buffer_size}, buffer_options);
void *buffer_ptr = buffer_tensor.data_ptr<int8_t>();
```

Remember do not call `cudaFree` on the pointer. RAII semantics will give the memory back to the allocator.

== Using CUBLAS, CUSPARSE, CUSolverDn

=== Handles

When writing pure CUDA/C++ code, you manually call `cusparseCreate`. However, this introduces milliseconds-level delay on CPU side.

LibTorch has API that automatically manages a pool of handles:
```cpp
#include <ATen/cuda/CUDAContext.h>
auto handle = at::cuda::getCurrentCUDASparseHandle();
```

=== Buffers

Pre-allocate buffers and pass pointers into CUSPARSE API calls through `torch.empty()`.

=== Batched Matrix Multiplication

- To broadcast, set stride to 0.
- It is possible to broadcast `rowptr` but not `colind` and `values`.

== Debug layer by layer

A CUDA extension is roughly split into 4 parts:
1. CUDA kernel
2. C++ wrapper
3. Data passed from Python to C++
4. Python wrapper

== What to Reference

The PyTorch C++ #link("https://pytorch.org/cppdocs/api/library_root.html")[documentation] is very old. It is a better choice to search in the PyTorch #link("https://github.com/pytorch/pytorch")[github repo] and read the source code.
