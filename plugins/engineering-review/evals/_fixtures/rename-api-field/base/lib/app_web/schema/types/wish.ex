defmodule AppWeb.Schema.Types.Wish do
  @moduledoc "The wish type, queried by the mobile app and the web front."
  use Absinthe.Schema.Notation

  object :wish do
    field :id, non_null(:id)
    @desc "What the member would like to do."
    field :title, non_null(:string)
  end

  input_object :create_wish_input do
    field :title, non_null(:string)
  end
end
