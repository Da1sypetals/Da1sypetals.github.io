
#import "@preview/shiroa:0.1.2": *

#show: book

#book-meta(
  title: "Petals Book",
  authors: ("Da1sypetals",),
  summary: [
    = Petals Book
    = #emoji.bread Welcome!
    - #chapter("content/welcome.typ")[This is Da1sypetals!]


    = #emoji.book Takedowns

    - #chapter("content/ipc/try_impl_ipc.typ")[Try to implement IPC]
    - #chapter("content/CG/cg.typ")[Conjugate Gradient Method]
    - #chapter("content/xmm/xmm.typ")[XMM]
    - #chapter("content/LsmTree/lsm.typ")[LSM Tree]
    - #chapter("content/raddy/diffroad.typ")[The road to diff]
      - #chapter("content/raddy/raddy.typ")[Raddy Devlog]

    - #chapter("content/simulation/main.typ")[Simulation]
      - #chapter("content/simulation/math-details.typ")[Some math details]
      - #chapter("content/simulation/TrustRegion.typ")[Read Paper: Trust Region Elastic Optimization]
    - #chapter("content/triton/triton_pitfalls.typ")[Triton common pitfalls]

    = #emoji.wrench References
    - #chapter("content/utils/backup-repo.typ")[Sites to backup your repo]
    - #chapter("content/utils/unlock-music.typ")[Encrypted music format]


    = 🎼 歌
    - #chapter("content/song/songs.typ")[ 我会唱的歌  ]


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