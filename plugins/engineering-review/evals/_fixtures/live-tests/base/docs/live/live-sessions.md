# Live sessions

## What it does

An online activity is held in a live room. Each run of the room is a session: the host opens it, starts it and ends
it. An activity's current session is its latest one.

## Data

```mermaid
erDiagram
  activities ||--o{ live_sessions : "runs"
  live_sessions {
    uuid id PK
    uuid activity_id FK
    string status "waiting, live or ended"
    timestamp activity_starts_at "the activity's start when the run opened, in UTC"
  }
```

```mermaid
stateDiagram-v2
  [*] --> waiting: openLive
  waiting --> live: startLive
  live --> ended: endLive
```

## Entry points

- `openLive`, `startLive`, `endLive` mutations, for the activity's host — `lib/app_web/schema/mutations/live.ex`
