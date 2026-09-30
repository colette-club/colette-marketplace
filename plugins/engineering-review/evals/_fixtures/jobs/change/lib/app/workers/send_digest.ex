defmodule App.Workers.SendDigest do
  use Oban.Worker, queue: :mailers

  alias App.Accounts
  alias App.Digests
  alias App.Mailer

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"member_id" => member_id}}) do
    member = Accounts.get_member!(member_id)
    member |> Digests.build() |> Mailer.deliver()
    :ok
  end
end
