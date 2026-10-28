# Live sessions

## What it does

Each online activity has one live room, opened the first time someone connects to it. The media server signs every
webhook it sends; `MediaServerSignature` turns a signed connection into a `Live.Connection` through the configured
`Live.Adapter`, and refuses an unsigned body with 401. Each person's first connection to a room is recorded as their
participation, once per person and room; it publishes `LiveParticipationRecorded`, which confirms the person's
attendance. Every signed event is answered 200, so the media server does not send it
again; a connection that cannot be recorded is logged.

## How it works

```mermaid
sequenceDiagram
  participant MS as Media server
  participant P as MediaServerSignature
  participant W as MediaServerController
  participant C as RecordConnection
  participant DB as Repo
  MS->>P: POST /webhooks/media-server (signed)
  P->>P: Live.verify_webhook → Connection, ignored, or 401
  P->>W: create(conn)
  W->>C: run(connection)
  C->>DB: open the room if needed
  C->>DB: insert the participation, once per person and room
  W-->>MS: 200 (a failure is logged)
```

## Data

```mermaid
erDiagram
  live_sessions ||--o{ live_participations : has
  users ||--o{ live_participations : connects
  live_participations {
    uuid id PK
    uuid session_id FK
    uuid user_id FK
    timestamp first_joined_at
  }
```

## Interactions

| Direction | What | Counterpart |
|---|---|---|
| Calls | `Live.Adapter` (configured) | the media server |

## Entry points

- `POST /webhooks/media-server` — `lib/app_web/controllers/media_server_controller.ex`
