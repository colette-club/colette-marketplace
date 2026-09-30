# Formatting

## What it does
Formats values for display. Dates are shown as `DD/MM/YYYY`. Prices arrive in euro cents: zero is shown as "Free", positive amounts as euros with two decimals ("12.50 €"). Negative prices are not accepted.

## Entry points
- `App.Formatting.format_date/1`
- `App.Formatting.format_price/1`
