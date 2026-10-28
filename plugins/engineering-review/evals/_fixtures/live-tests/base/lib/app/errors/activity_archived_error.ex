defmodule App.Errors.ActivityArchivedError do
  use App.ExErrors

  defexerror(message: "This activity is archived")
end
