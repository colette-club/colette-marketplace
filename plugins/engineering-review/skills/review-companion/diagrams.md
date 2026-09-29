# Diagram guide

Diagrams are mermaid code blocks inside the report. They render on GitHub, in most editors and in the Claude app. Draw one when a picture explains something faster than a sentence; skip it when one sentence is enough.

## Which diagram for which finding

| Finding about | Diagram |
|---|---|
| Race, lost update, duplicate processing, async or cancellation | `sequenceDiagram`: two actors side by side, the failure, then the fixed version |
| Transaction boundaries, effects before or after commit | `sequenceDiagram` with a `rect` around what is inside the transaction |
| Side effects set in motion | `flowchart LR` effect graph with the styles below |
| Missing or untested branch, error path | `flowchart` with each branch marked ✅ or ❌ |
| Layering, boundary or Demeter violation, coupling | Module `flowchart`, offending edge in red |
| Over-complex solution (EP-D12) | Before/after `flowchart`: what was built, and the minimal version |
| Schema or data-model change | `erDiagram`, before and after |
| Lifecycle or status field | `stateDiagram-v2`, the missing or illegal transition highlighted |
| N+1, blocking migration | `sequenceDiagram`: 1 + N round trips next to one batched query; writes waiting on an index build |
| Refactoring suggestion | Before/after `flowchart` or `classDiagram` |
| Risk map | `quadrantChart` |
| Docs impact | `flowchart` from code to doc pages, each page updated, stale or missing |

## Rules

- **Only these diagram types:** `flowchart`, `sequenceDiagram`, `erDiagram`, `stateDiagram-v2`, `classDiagram`, `quadrantChart`. Others may not render everywhere.
- One idea per diagram, at most about 12 nodes.
- Real names from the code (`create_referral/2`, `listings`), never placeholders.
- Put a one-line caption under each diagram saying what to look at, and a legend whenever colours carry meaning.
- Quote every node label that contains spaces, punctuation, parentheses, slashes or emoji: `A["create_referral/2"]`.
- Keep `classDef` names and colours below, so every report reads the same.

## Styles

```mermaid
flowchart LR
  A["added"]:::new --> B["changed"]:::changed --> C["removed"]:::removed
  D[/"external call"/]:::external --> E[/"message to a person"/]:::people --> F[/"leaves the app"/]:::boundary
  classDef new fill:#bbf7d0,stroke:#15803d
  classDef changed fill:#fde68a,stroke:#b45309
  classDef removed fill:#e5e7eb,stroke:#6b7280,stroke-dasharray:4 3
  classDef external fill:#fecaca,stroke:#b91c1c
  classDef people fill:#e9d5ff,stroke:#7e22ce
  classDef boundary fill:#ffffff,stroke:#b91c1c,stroke-dasharray:4 3
```

Legend: green added · amber changed · grey dashed removed · red external call · purple message to a person · red dashed leaves the app.

## Patterns

**Race (two actors, then the fix).**

```mermaid
sequenceDiagram
  participant A as Request A
  participant B as Request B
  participant DB
  A->>DB: read invites_remaining → 1
  B->>DB: read invites_remaining → 1
  A->>DB: check ≥ 1 ✓ · write 0
  B->>DB: check ≥ 1 ✓ · write 0
  Note over DB: 2 referrals, 1 invite spent
```

**Transaction boundary.**

```mermaid
sequenceDiagram
  participant S as create_referral/2
  participant DB
  participant M as Mailer
  rect rgb(254, 243, 199)
    Note over S,DB: inside the transaction
    S->>DB: insert referral
    S->>M: send invite email
    S->>DB: update invites_remaining
  end
  Note over M: the email is gone even if the commit fails
```

**Effect graph.**

```mermaid
flowchart LR
  C["create_referral/2"]:::changed --> E(["event ReferralCreated"]):::removed
  E -.-> H["NotifyReferrer"]:::removed
  C --> M[/"✉ invite email · irreversible"/]:::people
  classDef changed fill:#fde68a,stroke:#b45309
  classDef removed fill:#e5e7eb,stroke:#6b7280,stroke-dasharray:4 3
  classDef people fill:#e9d5ff,stroke:#7e22ce
```

**Untested branches.**

```mermaid
flowchart TD
  S["archive_wish/2"] --> A{"wish found?"}
  A -- no --> NF["error not_found ❌ untested"]
  A -- yes --> B{"already archived?"}
  B -- yes --> AA["error already_archived ❌ untested"]
  B -- no --> OK["ok archived wish ✅ tested"]
```

**Minimal solution (EP-D12).**

```mermaid
flowchart LR
  subgraph built["What was built"]
    O1["charge/1"] --> F["PaymentProviderFactory"] --> R["ProviderRegistry"] --> P1["StripeProvider"]
  end
  subgraph minimal["Minimal version"]
    O2["charge/1"] --> P2["Stripe client"]
  end
```

**Schema change.**

```mermaid
erDiagram
  CITIES ||--o{ LISTINGS : has
  LISTINGS {
    uuid id PK
    uuid city_id FK "no index"
    datetime archived_at
    datetime inserted_at
  }
```

**Lifecycle.**

```mermaid
stateDiagram-v2
  [*] --> active
  active --> archived: archive_wish
  archived --> active: restore_wish (missing)
```

**Risk map.**

```mermaid
quadrantChart
  title Where to look closely
  x-axis Rarely changed --> Often changed
  y-axis Low criticality --> High criticality
  quadrant-1 Look closely
  quadrant-2 Critical but stable
  quadrant-3 Low risk
  quadrant-4 Busy but low stakes
  "payments/charge.py": [0.8, 0.9]
  "admin/routes.py": [0.3, 0.8]
  "docs/billing.md": [0.2, 0.1]
```
