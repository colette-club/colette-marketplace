defmodule App.Live.Room do
  @moduledoc "The name of an activity's live room on the media server."

  @prefix "activity-"

  @spec name(binary()) :: String.t()
  def name(activity_id) when is_binary(activity_id), do: @prefix <> activity_id

  @spec activity_id(String.t()) :: {:ok, binary()} | :error
  def activity_id(@prefix <> activity_id), do: {:ok, activity_id}
  def activity_id(_name), do: :error
end
