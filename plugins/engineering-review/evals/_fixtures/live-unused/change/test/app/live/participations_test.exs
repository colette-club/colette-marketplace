defmodule App.Live.ParticipationsTest do
  use App.DataCase, async: true
  use ExEventBus.Testing, ex_event_bus: App.EventBus

  alias App.Live.{Events, Participation, Participations}

  describe "record_participation/4" do
    test "when a viewer joins the run for the first time" do
      session = insert(:live_session)
      member = insert(:user)

      assert {:ok, %Participation{user_id: user_id, role: "viewer"}} =
               Participations.record_participation(session, member.id, "viewer")

      assert user_id == member.id
      assert_event_received(Events.LiveParticipationRecorded)
    end

    test "when the host joins the run" do
      session = insert(:live_session)
      host = insert(:user)

      assert {:ok, %Participation{role: "host"}} = Participations.record_participation(session, host.id, "host")
    end

    test "when the person already joined the run" do
      session = insert(:live_session)
      member = insert(:user)
      insert(:live_participation, session: session, user: member, role: "viewer")

      assert {:ok, :already_recorded} = Participations.record_participation(session, member.id, "viewer")
      refute_event_received(Events.LiveParticipationRecorded)
    end

    test "when the role is neither host nor viewer" do
      session = insert(:live_session)
      member = insert(:user)

      assert {:error, %Ecto.Changeset{errors: [role: _]}} = Participations.record_participation(session, member.id, "admin")
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
