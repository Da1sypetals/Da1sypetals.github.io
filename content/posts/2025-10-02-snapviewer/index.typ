#import "/config.typ": template, tufted
#show: template.with(
  title: "SnapViewer: Faster PyTorch Memory Allocation Viewer",
  date: datetime(year: 2025, month: 10, day: 1),
  lang: "en",
)

== Background

When training models with PyTorch, out-of-memory (OOM) errors are common. When simple methods no longer work, analyzing the memory footprint may be required.

At this point, you might come across this #link("https://docs.pytorch.org/docs/stable/torch_cuda_memory.html")[documentation], which teaches you how to record a memory snapshot and visualize it.

However, there's a major issue: the website is extremely laggy. If your model is large, with snapshots reaching hundreds of MB, the website becomes unbearably slow, with frame rates dropping as low as 2–3 frames per minute.

I looked into the website's JavaScript code:
1. Manually loads Python pickle files;
2. Re-parses the raw data into graphical representations each time the viewport changes.

== Inspiration

My current work includes optimizing a deep learning model. I encountered this issue while working with a snapshot of a model with several billion parameters.

TL;DR: The graphical data from the memory snapshot is parsed and represented as a massive triangle mesh, leveraging existing rendering libraries.

Here's a snapshot of over 100 MB running smoothly on my integrated GPU:

#figure(image("snapviewer.gif"))

== Implementation

=== Snapshot (De)serialize

**Initial implementation:** Convert the dict to a JSON file.

**Optimizations:**
1. Raw JSON is too large → compress it in-memory before writing.
2. During visualization, read the ZIP from disk and decompress in-memory.

=== Rendering & Interaction

This part is implemented in Rust.

**Rendering:**
- Since allocation data remains static, all allocations are combined into a single large mesh and sent to the GPU once.
- Library Used: three-d

**World-to-Window Coordinate Conversion:**
1. Convert window coordinates to world coordinates.
2. Convert world coordinates to memory positions.

=== Query

After using this tool at work, I frequently needed to search in the memory snapshot. I decided not to reinvent wheels: I just connect to an in-memory SQLite database.

---

If you've struggled with PyTorch memory snapshots, #link("https://github.com/Da1sypetals/SnapViewer")[check it out]! Contributions & feedback welcome.
