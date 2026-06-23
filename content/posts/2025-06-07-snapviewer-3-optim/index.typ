#import "/config.typ": template, tufted
#show: template.with(
  title: "SnapViewer Devlog #3: Optimizations",
  date: datetime(year: 2025, month: 6, day: 7),
  lang: "en",
)

*Intro: Troubleshooting Memory and Speed Performance*

*Disclaimer:* I develop and test primarily on Windows using the latest stable Rust toolchain and CPython 3.13.

== 1. Background and Motivation

SnapViewer handles large memory snapshots effectively. However, when processing extremely large dumps (e.g., a 1.3 GB snapshot), we encountered serious bottlenecks:

- Format conversion triggered memory peaks around 30 GB.
- Data loading caused another ~30 GB spike.

== 2. Profile-Guided Optimization

I decomposed the data-loading pipeline:
- Reading the compressed file
- Extracting JSON from the compressed stream
- Deserializing JSON into Rust structures
- Populating an in-memory SQLite database
- Building the triangle mesh on CPU
- Initializing the rendering window

=== Eliminating Redundant Clones

- *First attempt:* switch from `Vec<T>` to `&[T]`. Failed due to lifetimes.
- *Final solution:* use `Arc<[T]>`. No significant overhead observed.

=== Early Deallocation of Intermediate Structures

- Use scoped blocks to limit lifetimes
- Explicitly invoke `drop()` on unneeded buffers

Peak memory dropped by roughly one-third.

== 3. Sharding JSON Deserialization

- Shard JSON data into chunks of at most 50,000 entries.
- Deserialize each chunk independently.

== 4. Redesigning the Snapshot Format

I split the snapshot into two files:
- *allocations.json:* lightweight JSON with timestamps and sizes.
- *elements.db:* SQLite database holding call-stack text.

At runtime:
- Load `allocations.json` into memory.
- Open `elements.db` on disk.
- On click, query `elements.db`.

== 5. Results and Lessons

After these optimizations:
- No longer spikes to 60+ GB of RAM.
- Starts up much faster.
- Maintains smooth rendering.

What I learned:
- Do not always load everything into memory.
- SQLite is a good choice when you need disk storage with intelligent caching.
