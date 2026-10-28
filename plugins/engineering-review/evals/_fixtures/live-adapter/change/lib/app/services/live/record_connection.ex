defmodule App.Services.Live.RecordConnection do
  @moduledoc """
  Records who connected to an activity's live room, as LiveKit reports it: a
  person's first connection to the current run is their participation, with
  the role their token carries. Any other event, a room that is not an
  activity's, or a participant without a role is ignored.
  """

  alias App.Live
  alias App.Live.Room

  @spec run(map(), keyword()) :: {:ok, term()} | {:error, term()}
  def run(event, opts \\ [])

  def run(
        %{
          "event" => "participant_joined",
          "room" => %{"name" => room},
          "participant" => %{"identity" => identity} = participant
        },
        opts
      ) do
    role = participant |> Map.get("metadata", "") |> role()

    room
    |> Room.activity_id()
    |> record(identity, role, opts)
  end

  def run(%{}, _opts), do: {:ok, :ignored}

  defp record({:ok, activity_id}, identity, role, opts) when role in ["host", "viewer"] do
    with {:ok, session} <- Live.get_or_create_session(activity_id, opts),
         do: Live.record_participation(session, identity, role, opts)
  end

  defp record({:ok, _activity_id}, _identity, _role, _opts), do: {:ok, :ignored}
  defp record(:error, _identity, _role, _opts), do: {:ok, :ignored}

  defp role(metadata) when is_binary(metadata) do
    case JSON.decode(metadata) do
      {:ok, %{"role" => role}} -> role
      _no_role -> nil
    end
  end

  defp role(_metadata), do: nil
end
