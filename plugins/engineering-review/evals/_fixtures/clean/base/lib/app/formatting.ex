defmodule App.Formatting do
  @moduledoc "Formats values for display."

  @doc "Formats a date as `DD/MM/YYYY`."
  def format_date(%Date{} = date), do: Calendar.strftime(date, "%d/%m/%Y")
end
