
#import "@preview/shiroa:0.1.2": *

#show: book

#book-meta(
  title: "Da1sypetals Bookly Blog",
  authors: ("Da1sypetals",),
  summary: [
    = Da1sypetals Bookly Blog

    - #chapter("content/xmm/xmm.typ")[XMM]
    - #chapter("content/CG/cg.typ")[Conjugate Gradient Method]


    = Sample Pages
    - #chapter("content/Sample/sample-page.typ")[Sample Page]
      - #chapter("content/Sample/subchapter.typ")[Subchapter]
  ]
)



// re-export page template
#import "/templates/page.typ": project
#let book-page = project



#build-meta(
  dest-dir: "./docs",
)