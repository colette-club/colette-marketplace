---
type: regex
pattern: '## 9\. Conversation(?:(?!\n## )[\s\S])*(ReferralCreated|NotifyReferrer)'
target: { source: file, path: '.reviews/referrals.md' }
---
