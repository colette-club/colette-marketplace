# Live sessions

## What it does

Each online activity has one live room, opened the first time someone connects to it. The media server signs every
webhook it sends; `MediaServerSignature` turns a signed connection into a `Live.Connection` through the configured
`Live.Adapter`, and refuses an unsigned body with 401.

## Interactions

| Direction | What | Counterpart |
|---|---|---|
| Calls | `Live.Adapter` (configured) | the media server |
