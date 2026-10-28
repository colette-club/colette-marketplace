defmodule AppWeb.Support.RawBody do
  @moduledoc "The request body as received, kept by the endpoint's body reader for signature checks."

  @spec read(Plug.Conn.t()) :: binary()
  def read(%Plug.Conn{assigns: %{raw_body: raw_body}}), do: IO.iodata_to_binary(raw_body)
end
