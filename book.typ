
#import "@preview/shiroa:0.1.2": *

#show: book

#book-meta(
  title: "shiroa",
  summary: [
    = Hello world
    - #chapter("content/Sample/sample-page.typ")[Sample Page]
      - #chapter("content/Sample/subchapter.typ")[Subchapter]
    - #chapter("content/CG/cg.typ")[Conjugate Gradient Method]
    - #chapter("content/xmm/xmm.typ")[XMM]
  ]
)



// re-export page template
#import "/templates/page.typ": project
#let book-page = project



#build-meta(
  dest-dir: "./docs",
)