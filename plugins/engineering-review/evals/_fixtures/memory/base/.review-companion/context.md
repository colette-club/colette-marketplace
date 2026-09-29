# Review context

Facts confirmed by people during reviews. The review companion shows the entries that apply to a change and asks whether they are still true.

## Card data must never be logged
- **Fact:** Legal asked that card numbers and IBANs are never written to logs.
- **Applies to:** `lib/app/payments/**`
- **Confirmed by:** reviewer, 2026-03-02
- **Recheck by:** 2026-06-01

## Reporting export runs nightly
- **Fact:** The reporting export reads this data every night at 02:00 UTC.
- **Applies to:** `lib/app/other/**`
- **Confirmed by:** author, 2026-09-10
- **Recheck by:** 2027-01-01
