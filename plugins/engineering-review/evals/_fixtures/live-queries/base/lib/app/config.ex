defmodule App.Config do
  @moduledoc """
  Reads the application's settings. `put_env/3` overrides a setting for the
  calling process and the processes it starts, so async tests can each set
  their own; without an override it reads the application environment.
  Every module reads its settings through here.
  """

  @spec fetch_env!(atom(), atom()) :: term()
  def fetch_env!(app, key) do
    case lookup(app, key) do
      {:ok, value} -> value
      :error -> Application.fetch_env!(app, key)
    end
  end

  @spec put_env(atom(), atom(), term()) :: :ok
  def put_env(app, key, value) do
    Process.put({__MODULE__, app, key}, value)
    :ok
  end

  defp lookup(app, key) do
    [self() | Process.get(:"$callers", [])]
    |> Enum.find_value(:error, &override(&1, {__MODULE__, app, key}))
  end

  defp override(pid, entry_key) do
    pid
    |> Process.info(:dictionary)
    |> find_override(entry_key)
  end

  defp find_override({:dictionary, dictionary}, entry_key) do
    case List.keyfind(dictionary, entry_key, 0) do
      {^entry_key, value} -> {:ok, value}
      nil -> nil
    end
  end

  defp find_override(nil, _entry_key), do: nil
end
