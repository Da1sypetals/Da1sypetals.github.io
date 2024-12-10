
#import "@preview/shiroa:0.1.2": *

#show: book

#book-meta(
  title: "Da1sypetals' Bookblog",
  authors: ("Da1sypetals",),
  summary: [
    = Da1sypetals' Bookblog
    = #emoji.bread Welcome!
    - #chapter("content/welcome.typ")[This is Da1sypetals!]


    = #emoji.book Articles

    - #chapter("content/ipc/try_impl_ipc.typ")[Try to implement IPC]
    - #chapter("content/CG/cg.typ")[Conjugate Gradient Method]
    - #chapter("content/xmm/xmm.typ")[XMM]

    = #emoji.wrench Utilities
    - #chapter("content/archlinux/arch.typ")[Arch Linux Use Tips]

    = #emoji.notes Fun
    - #chapter("content/fun/songs.typ")[Songs]


    = #emoji.construction Sample Pages
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