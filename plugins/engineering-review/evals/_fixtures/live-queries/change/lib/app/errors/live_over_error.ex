defmodule App.Errors.LiveOverError do
  use App.ExErrors

  defexerror(message: "The host has ended this live")
end
