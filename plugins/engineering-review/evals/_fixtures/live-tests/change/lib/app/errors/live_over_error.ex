defmodule App.Errors.LiveOverError do
  use App.ExErrors

  defexerror(message: "This live is over")
end
