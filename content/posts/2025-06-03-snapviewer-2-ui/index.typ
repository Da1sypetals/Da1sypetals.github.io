#import "/config.typ": template, tufted
#show: template.with(
  title: "Snapviewer Devlog #2: UI",
  date: datetime(year: 2025, month: 6, day: 3),
  lang: "en",
)

*Intro: Building the UI as a Hybrid Rust & Python Application*

== The Initial Vision

My core requirements:
- *Interactive Display:* When an allocation is clicked, display its size, call stack, etc.
- *SQL REPL:* Execute SQL queries against the underlying database.
- *Non-Blocking Operations.*

== Early Attempts and Roadblocks

=== Web: Rust to WASM

Hit a wall with library versioning issues. Pivoted.

=== TUI: Terminal User Interface

*Ratatui:* Got demos running, but finding an open-source example matching my layout failed.

*Textual & AI-Powered Development:*
I fed my requirements to several LLMs. Claude's initial results were impressive. After refinement, I had a working TUI demo.

== Combining Rust and Python

I used PyO3 to expose Rust structures and bind functions to Python.

=== Designing App Structure

My initial idea:
- *Main Thread:* Renders the TUI and accepts REPL inputs.
- *Spawned Thread:* Runs the infinite loop for the Snapshot Viewer.

However, `winit` requires the window to run on the main thread.

=== Attempt 1: Multiprocessing

- Start the application and load snapshot data.
- Spawn a new process to run the TUI.
- Run the Viewer in the parent process.

The challenge was IPC. I experimented with `multiprocessing.Queue` and shared byte arrays.

=== Attempt 2: Threading

I realized I could use multithreading instead:
- Spawn a thread and start the TUI on that thread.
- Start the viewer on the main thread.

The culprit? The Global Interpreter Lock (GIL). By explicitly releasing the GIL during the viewer's render loop, the TUI was free to update.

=== An Alternative: GUI with PyQt

Claude translated my TUI code into PyQt in minutes.

(I finally switched to Tkinter for compatibility.)

== Wrapping Up

This journey highlights the flexibility of combining Rust's performance with Python's rapid development.
