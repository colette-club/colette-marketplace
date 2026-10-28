defmodule App.Live.ParticipationsTest do
  use App.DataCase, async: true
  use ExEventBus.Testing, ex_event_bus: App.EventBus

  alias App.Live.{Events, Participation, Participations}

  describe "record_participation/3" do
    test "when the member joins the run for the first time" do
      session = insert(:live_session)
      member = insert(:user)

      assert {:ok, %Participation{user_id: user_id}} = Participations.record_participation(session, member.id)
      assert user_id == member.id
      assert_event_received(Events.LiveParticipationRecorded)
    end

    test "when the member already joined the run" do
      session = insert(:live_session)
      member = insert(:user)
      insert(:live_participation, session: session, user: member)

      assert {:ok, :already_recorded} = Participations.record_participation(session, member.id)
      refute_event_received(Events.LiveParticipationRecorded)
    end
  end

  describe "count_participants/1" do
    test "when two members joined the run" do
      session = insert(:live_session)
      insert(:live_participation, session: session)
      insert(:live_participation, session: session)

      assert Participations.count_participants(session.id) == 2
    end
  end
end
