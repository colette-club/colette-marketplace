defmodule App.Errors.NotFoundError do
  use App.ExErrors

  defexerror([:resource_type, :resource_id, message: "Resource not found"],
    required_fields: [:resource_type]
  )
end
