# App conventions

- Every mutation resolver in `lib/app_web/resolvers/` records an audit entry with `App.Audit.log(actor, action)` before it returns.
- Tests mirror the source path under `test/`.
