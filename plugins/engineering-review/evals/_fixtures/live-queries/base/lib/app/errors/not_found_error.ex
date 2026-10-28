defmodule App.Errors.NotFoundError do
  use App.ExErrors

  defexerror([:resource_type, message: "Resource not found"], required_fields: [:resource_type])
end
