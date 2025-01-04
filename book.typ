
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
    - #chapter("content/raddy/diffroad.typ")[The road to diff]
      - #chapter("content/raddy/raddy.typ")[Raddy Devlog]
      - #chapter("content/raddy/raddy-docs.typ")[Raddy Docs]

    - #chapter("content/xmm/xmm.typ")[Simulation]
      - #chapter("content/simulation/math/main.typ")[Math & Impl]
      - #chapter("content/simulation/TRfilter-PN/main.typ")[Paper: TRPN]

    = #emoji.wrench Utilities
    - #chapter("content/archlinux/arch.typ")[Arch Linux Use Tips]
    - #chapter("content/utils/utils.typ")[Arch Linux Use Tips]
    - #chapter("content/rust-tips/rust.typ")[Rust Tips]
      - #chapter("content/rust-tips/done-right.typ")[Done Right]
      - #chapter("content/rust-tips/cargo-tips.typ")[Cargo Tips]


    = 🎼 Fun
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