#!/usr/bin/env bash
# Writes 21 small modules (21 code files, about 130 lines) and 2 test files.
set -euo pipefail
mkdir -p lib/app/catalog test/app/catalog
for n in $(seq 1 21); do
  {
    echo "defmodule App.Catalog.Filter${n} do"
    echo "  @moduledoc \"Catalog filter ${n}.\""
    echo ""
    echo "  def apply(items), do: Enum.filter(items, &(&1.rank >= ${n}))"
    echo "end"
  } > "lib/app/catalog/filter_${n}.ex"
done
for n in 1 2; do
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
