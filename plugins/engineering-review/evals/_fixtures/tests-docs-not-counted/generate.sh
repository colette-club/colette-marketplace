#!/usr/bin/env bash
# Writes 18 code files, 18 test files and 6 doc pages: 42 files, of which 18 are code.
set -euo pipefail
mkdir -p lib/app/catalog test/app/catalog docs/catalog
for n in $(seq 1 18); do
  {
    echo "defmodule App.Catalog.Filter${n} do"
    echo "  @moduledoc \"Catalog filter ${n}.\""
    echo ""
    echo "  def apply(items), do: Enum.filter(items, &(&1.rank >= ${n}))"
    echo "end"
  } > "lib/app/catalog/filter_${n}.ex"
  {
    echo "defmodule App.Catalog.Filter${n}Test do"
    echo "  use ExUnit.Case, async: true"
    echo ""
    echo "  test \"keeps items ranked ${n} or more\" do"
    echo "    assert [%{rank: ${n}}] = App.Catalog.Filter${n}.apply([%{rank: 0}, %{rank: ${n}}])"
    echo "  end"
    echo "end"
  } > "test/app/catalog/filter_${n}_test.exs"
done
for n in $(seq 1 6); do
  {
    echo "# Catalog filters, part ${n}"
    echo ""
    echo "Filters $((n * 3 - 2)) to $((n * 3)) keep the items ranked at least their number."
  } > "docs/catalog/filters_${n}.md"
done
