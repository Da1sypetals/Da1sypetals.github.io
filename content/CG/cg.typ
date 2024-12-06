#import "/book.typ": book-page
#show: book-page.with(title: "XMM")
#set par(justify: true, leading: 1em)
#set heading(numbering: "1.")
#set text( font: ( "Libertinus Serif"),  size: 18pt, top-edge: 0.7em, bottom-edge: -0.3em)


= Conjugate Gradient

- CG
  - CGCGCG
  - asdfasdfasdf

== HEAD

$
Psi_"SNH"=mu/2 (I_2-3)-mu (I_3-1)+lambda/2 (I_3-1)^2
$

#let ff=$bold(upright(F))$
$
  (partial Psi_"SNH")/(partial"vec"(ff))=
  mu"vec"(ff)+[lambda(J-1)-mu](partial J)/(partial"vec"(ff))
  
$

$
  (partial^2 Psi_"SNH")/(partial"vec"(ff)^2)=
  lambda g_J g_J^T+mu/2 H_2+[lambda(J-1)-mu]H_J
  
$
