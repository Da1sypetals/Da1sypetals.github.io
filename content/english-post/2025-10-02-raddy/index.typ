#import "/config.typ": template, tufted
#show: template.with(
  title: "Raddy devlog: forward autodiff system",
  date: datetime(year: 2025, month: 10, day: 2),
  lang: "en",
)

*TL;DR:* I created #link("https://github.com/Da1sypetals/Raddy")[Raddy], a forward autodiff library, and #link("https://github.com/Da1sypetals/Symars")[Symars], a symbolic codegen library.

If you're interested, please give them a star and try them out!

== The Origin of the Story

I recently read papers on physical simulation and wanted to reproduce them. I started with #link("https://graphics.pixar.com/library/StableElasticity/paper.pdf")[Stable Neo-Hookean Flesh Simulation].

This involves:
- Computing derivatives of the constitutive energy model (first-order gradient, second-order Hessian).
- Assembling a large, sparse Hessian from small, dense Hessian submatrices — a delicate task prone to hard-to-debug bugs.

From #link("https://www.tkim.graphics/DYNAMIC_DEFORMABLES/")[Dynamic Deformables], I learned deriving these formulas is labor-intensive. Searching for alternatives:
- Symbolic differentiation with code generation.
- Automatic differentiation.

Tools for the former include MATLAB or SymPy; for the latter, deep learning libraries like PyTorch or more suitable ones like #link("https://github.com/patr-schm/TinyAD")[TinyAD].

Why TinyAD? Deep learning libraries differentiate at the tensor level, but I needed scalar-level differentiation for physical simulations.

A problem arose: these tools are in the C++ toolchain, and I'm not proficient in C++. So, I switched to Rust. This was the start of all troubles...

== A Path That Seems Simple

Rust lacks an automatic differentiation library for second-order Hessians. SymPy can generate Rust code, but it's buggy. I started with symbolic code generation, creating #link("https://github.com/Da1sypetals/Symars")[Symars].

SymPy's symbolic expressions are tree-structured. Code generation involves depth-first traversal: compute child expressions, then the current node's expression.

== Trying the Untrodden Path Again

To address this, I revisited automatic differentiation, aiming to adapt TinyAD for Rust.

=== Two Ways to Walk the Same Path

Initially, I considered two approaches:
- Write FFI bindings, as I don't know C++ well.
- Replicate TinyAD's logic.

Examining the codebase, I found the core logic was ~1000 lines — manageable to replicate. Thus, #link("https://github.com/Da1sypetals/Raddy")[Raddy] was born.

== Symbolic diff & Codegen: Implementation

Implementation details:
- Each scalar in the differentiation chain carries a gradient and Hessian, increasing memory overhead. I avoided implementing the `Copy` trait, requiring explicit cloning.
- Operator traits between `(&)Type` and `(&)Type` (four combinations) required repetitive code. I used Python scripts for simple string concatenation.
- Testing: I verified derivatives by generating symbolic `grad` and `hessian` code with Symars, cross-validating against Raddy's results.

== What about sparse matrices

Dense matrices store adjacent values contiguously, but sparse matrices don't. I implemented sparse Hessian assembly:

- Define a problem via the `Objective<N>` trait:

```rust
impl Objective<4> for SpringEnergy {
    type EvalArgs = f64; // restlength
    fn eval(&self, variables: &advec<4, 4>, restlen: &Self::EvalArgs) -> Ad<4> {
        let p1 = advec::<4, 2>::new(variables[0].clone(), variables[1].clone());
        let p2 = advec::<4, 2>::new(variables[2].clone(), variables[3].clone());
        let len = (p2 - p1).norm();
        let e = make::val(0.5 * self.k) * (len - make::val(*restlen)).powi(2);
        e
    }
}
```

- Specify input components' indices.
- Automatically assemble sparse `grad` and `hess`.
- Manually sum multiple `grad` and `hess`.

Before tests, Raddy was 2.2k lines; after, it ballooned to 18k lines, showing LOC is a poor metric.

Finally, I wrote a demo for fun and as an example.

#figure(image("raddy-mass-spring.gif"))

== Conclusion

Gains:
- Learned how automatic differentiation works.
- First time using AI for documentation.
- Happiness!
