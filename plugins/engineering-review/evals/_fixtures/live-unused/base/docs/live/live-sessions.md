# Live sessions

## What it does

An online activity runs in a live room. The media server reports every connection; the first one opens a run of the
live, and a viewer's first connection to a run is recorded once as their participation. A participation confirms the
member's registration as attended. The host's connections are not recorded.

## Data

```mermaid
erDiagram
  live_sessions ||--o{ live_participations : has
  live_sessions {
    uuid id PK
    uuid activity_id FK
    string status "waiting"
  }
  live_participations {
    uuid id PK
    uuid session_id FK
    uuid user_id FK
    timestamp first_joined_at
  }
```

## Interactions

- Publishes `LiveParticipationRecorded`, consumed by Communities' `ConfirmAttendance`.
- `participantCount` on a live session counts its participations: the members who took part.
