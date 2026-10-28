defmodule App.Live.ParticipationsTest do
  use App.DataCase, async: true
  use ExEventBus.Testing, ex_event_bus: App.EventBus

  alias App.Live.Events
  alias App.Live.Participation
  alias App.Live.Participations

  describe "record_participation/2" do
    test "when the person connects to the room for the first time" do
      session = insert(:live_session)
      user = insert(:user)

      assert {:ok, %Participation{session_id: session_id, user_id: user_id, first_joined_at: %DateTime{}}} =
               Participations.record_participation(session, user.id)

      assert session_id == session.id
      assert user_id == user.id
      assert_event_received(Events.LiveParticipationRecorded)
    end

    test "when the person connected to the room before" do
      session = insert(:live_session)
      user = insert(:user)
      first = insert(:live_participation, session: session, user: user, first_joined_at: ~U[2026-10-28 09:00:00.000000Z])

      assert {:ok, %Participation{id: id, first_joined_at: ~U[2026-10-28 09:00:00.000000Z]}} =
               Participations.record_participation(session, user.id)

      assert id == first.id
      assert Repo.aggregate(Participation, :count) == 1
      refute_event_received(Events.LiveParticipationRecorded)
    end
  end
end
