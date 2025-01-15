#import "/book.typ": book-page
#show: book-page.with(title: "Sample Page")

#show outline.entry: it => {
  if it.level == 1 {
    v(12pt, weak: true)
    strong(it)
  } else {
    let sz = 13pt - it.level * 0.5pt;
    let indent = "";
    let counter = 1;
    while counter < it.level {
      indent += $"    "$;
      counter += 1;
    }
    indent + text(size: sz)[#it]

   

  }
}

#outline()

 
// ################### Content ###################
#set heading(numbering: "1.")

= Rotation Variant SVD
- 在对能量hessian进行SVD分解 (and further, project to SPD) 的时候，需要是rotation variant的，也就是 $U, V$ 的*行列式的符号*要一样。
- 如果调库SVD，$U, V$ 的*行列式的符号*不一样怎么办？
  - TLDR：
  #image("svd.jpg", width: 60%)
  ```rust
fn rvsvd<const N: usize>(mat: &mat<N>) -> RvSvd<N> {
    let svd = mat.svd(true, true);
    let mut sgn = mat9::identity();
    let mut u = svd.u.unwrap();
    let mut vt = svd.v_t.unwrap();
    let mut sig = svd.singular_values;
    let su = u.determinant().signum();
    let sv = vt.determinant().signum();
    sgn[(N - 1, N - 1)] = su * sv;

    if su < 0.0 && sv > 0.0 {
        u = u * sgn;
    } else if su > 0.0 && sv < 0.0 {
        vt = sgn * vt;
    }
    sig[N - 1] *= sgn[(N - 1, N - 1)];
    RvSvd { u, sig, vt }
}
  ```

= Newton Raphson method

== 介绍
一般使用的有armijo condition和wolfe condition。

== 实例
=== #link("https://github.com/theodorekim/HOBAKv1", "HOBAK")

- `_S`: DOF mask to filter away constraints.
- 进行特定次数（20）的line search，每次步长缩小特定倍数（$beta$），然后下降到这20次中最小能量的位置。
- 如果搜索失败（每次能量都比初始能量大），那么就接受20次搜索后的步长 $beta^20$。

= Mass Matrix of Mesh
