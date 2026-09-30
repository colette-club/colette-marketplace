---
type: regex
pattern: '(ReferralCreated|NotifyReferrer)[^\n]*\|\s*(yes|✅|✔|✔️|intended|confirmed)\s*\|\s*$'
flags: im
match: not_contains
target: { source: file, path: '.reviews/referrals.md' }
---
