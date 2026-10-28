defmodule App.Errors.NotAnAttendeeError do
  use App.ExErrors

  defexerror(message: "You are not registered for this activity")
end
