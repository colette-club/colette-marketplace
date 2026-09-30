defmodule App.Formatting do
  @moduledoc "Formats values for display."

  @doc "Formats a date as `DD/MM/YYYY`."
  def format_date(%Date{} = date), do: Calendar.strftime(date, "%d/%m/%Y")

  @doc """
  Formats a price given in euro cents: `0` is shown as `"Free"`, any positive amount
  as euros with two decimals, for example `1250` as `"12.50 €"`.
  """
  def format_price(0), do: "Free"

  def format_price(cents) when is_integer(cents) and cents > 0 do
    euros = div(cents, 100)
    remainder = cents |> rem(100) |> Integer.to_string() |> String.pad_leading(2, "0")
    "#{euros}.#{remainder} €"
  end
end
