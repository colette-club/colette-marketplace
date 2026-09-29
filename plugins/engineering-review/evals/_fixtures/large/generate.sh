#!/usr/bin/env bash
# Writes 45 new modules of ~40 lines each (over 1,500 lines, over 40 files).
set -euo pipefail
mkdir -p lib/app/catalog
for n in $(seq 1 45); do
  {
    echo "defmodule App.Catalog.Item${n} do"
    echo "  @moduledoc \"Catalog item ${n}.\""
    for f in $(seq 1 12); do
      echo ""
      echo "  def attribute_${f}(%{value: value}), do: value * ${f}"
      echo "  def attribute_${f}(_other), do: 0"
    done
    echo "end"
  } > "lib/app/catalog/item_${n}.ex"
done
