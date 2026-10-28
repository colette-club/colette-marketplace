defmodule App.Errors.LiveRoomNotOpenError do
  use App.ExErrors

  defexerror(message: "The live room opens 15 minutes before the activity starts")
end
