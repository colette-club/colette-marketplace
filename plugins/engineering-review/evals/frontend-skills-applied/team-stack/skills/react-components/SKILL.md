---
name: react-components
description: Team rules for React components: keys, effects and async handlers. Use when writing or reviewing React or TSX components.
---

# React components

- **REACT-1** — List items use a stable key from the data (an id), never the array index.
- **REACT-2** — An async event handler handles failure and tells the user; a promise is never left without a `catch`.
