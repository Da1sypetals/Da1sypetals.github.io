#import "/book.typ": book-page
#show: book-page.with(title: "Sample Page")

_2024.12.29_


= #link("https://github.com/Da1sypetals/Raddy", "Raddy")  Docs


= `Ad<const N: usize>`
- Generics
  - `N`: \# dimension of *variable* (that requires derivatives).
- Notes
  - Computes on precision `f64`.

#set heading(numbering: "1.")

= Constructors
== `pub fn ad(value: f64) -> Ad<1>`
- Initializes a differentiated scalar.

== `pub fn vec<const L: usize>(values: &[f64]) -> SVector<Ad<L>, L>`
- Initializes a differentiated vector.
- _Panics_ if size mismatch.

== `pub fn val(value: f64) -> Ad<1>`
- Initializes a constant scalar.


== `pub fn valvec<const L: usize>(values: &[f64]) -> SVector<Ad<L>, L>`
- Initializes a constant vector.
- _Panics_ if size mismatch.


= Supports
- Elementary function ($sin, cosh, exp, ln, $ _etc_.)
  - Does *not* support $"atan"$, please use $"atan2"$ instead.

- Norms and determinant for matrices.
- Matrix multiplication.
- SVD, although you should not use it (for some numerical problems).