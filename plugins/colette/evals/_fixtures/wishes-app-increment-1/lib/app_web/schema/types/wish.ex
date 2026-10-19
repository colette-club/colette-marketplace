defmodule AppWeb.Schema.Types.Wish do
  @moduledoc "The wish type, queried by the mobile app and the web front."
  use Absinthe.Schema.Notation

  object :wish do
    field :id, non_null(:id)
    @desc "What the member would like to do."
    field :title, non_null(:string)
    @desc "When the member archived the wish; null while it is active."
    field :archived_at, :datetime
  end

  input_object :create_wish_input do
    field :title, non_null(:string)
  end

  object :wish_mutations do
    @desc "Archives one of the member's wishes; it leaves their list."
    field :archive_wish, :wish do
      arg :id, non_null(:id)
      resolve &AppWeb.Resolvers.Wishes.archive_wish/3
    end
  end
end
