# templates/dialyzer_ignore.exs — becomes the app's .dialyzer_ignore.exs
# Dialyzer warnings that predate the guardrails, one per line, each ending with a comma.
# It may only shrink: an entry that no longer matches fails the build.
[]
