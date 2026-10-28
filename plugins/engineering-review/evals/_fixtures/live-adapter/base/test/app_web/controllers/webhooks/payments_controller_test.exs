defmodule AppWeb.Webhooks.PaymentsControllerTest do
  use AppWeb.ConnCase, async: true

  import Mox

  alias App.Payments.PaymentEvent

  setup :verify_on_exit!

  describe "create/2" do
    test "when the adapter verifies a succeeded payment", %{conn: conn} do
      payment = insert(:payment, payment_intent_id: "pi_1", status: "pending")

      expect(App.Payments.AdapterMock, :verify_webhook, fn "signature", _body ->
        {:ok, %PaymentEvent{payment_intent_id: "pi_1", outcome: :succeeded}}
      end)

      conn = conn |> put_req_header("stripe-signature", "signature") |> post("/webhooks/payments", "{}")

      assert json_response(conn, 200) == %{"status" => "ok"}
      assert Repo.reload(payment).status == "succeeded"
    end
  end
end
