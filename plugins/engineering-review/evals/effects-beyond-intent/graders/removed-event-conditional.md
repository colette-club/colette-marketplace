---
type: regex
pattern: '### F-\d+ (?=(?:(?!\n##)[\s\S])*?(ReferralCreated|NotifyReferrer))(?=(?:(?!\n##)[\s\S])*?Status[^\n]*(conditional|question))'
flags: i
target: { source: file, path: '.reviews/referrals.md' }
---
