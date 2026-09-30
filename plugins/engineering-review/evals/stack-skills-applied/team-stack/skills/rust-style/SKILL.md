---
name: rust-style
description: Team rules for Rust crates: error types, unsafe and clippy. Use when writing or reviewing Rust code.
---

# Rust style

- **RS-1** — Library errors use `thiserror` enums, never `Box<dyn Error>`.
