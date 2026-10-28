defmodule App.Errors.LiveRoomNotOpenError do
  use App.ExErrors

  defexerror(message: "The live room is not open yet")
end
