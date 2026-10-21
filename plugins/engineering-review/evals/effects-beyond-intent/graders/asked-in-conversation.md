---
type: regex
pattern: '## 10\. Conversation(?:(?!\n## )[\s\S])*(ReferralCreated|NotifyReferrer)'
target: { source: file, path: '.reviews/referrals.md' }
---
