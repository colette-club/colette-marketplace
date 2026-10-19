# Archive wishes — design

## Why

Members' wish lists fill up with wishes they gave up on. They want to put those aside without deleting them.

## End goal

Members archive a wish they no longer want; archived wishes leave their list, and they can see and restore them from an Archived tab, in the mobile app and the web front.

## Increments

### Increment 1 — Archive a wish

- **Delivers:** a member archives a wish through the `archiveWish` mutation; it leaves `list_wishes/1`.
- **Deployable alone:** yes. A nullable `archived_at` column; the previous version ignores it.
- **Consumers:** the mobile app and the web front add an Archive action; the API deploys first.
- **Code files:** 4 — migration, `lib/app/wishes/wish.ex`, `lib/app/wishes.ex`, `lib/app_web/schema/types/wish.ex`
- [x] PR #8

### Increment 2 — See archived wishes in an Archived tab

- **Delivers:** a member lists their archived wishes through a new `archivedWishes` GraphQL field, backed by `list_archived_wishes/1`.
- **Deployable alone:** yes. A new field; nothing existing changes.
- **Consumers:** the mobile app and the web front add the Archived tab; the API deploys first.
- **Code files:** 2 — `lib/app/wishes.ex`, `lib/app_web/schema/types/wish.ex`
- [ ] Not shipped

### Increment 3 — Restore an archived wish

- **Delivers:** a member restores an archived wish through a `restoreWish` mutation, backed by `restore_wish/1`.
- **Deployable alone:** yes. A new mutation.
- **Consumers:** the mobile app and the web front add a Restore action in the Archived tab; the API deploys first.
- **Code files:** 3 — `lib/app/wishes/wish.ex`, `lib/app/wishes.ex`, `lib/app_web/schema/types/wish.ex`
- [ ] Not shipped
