Mox.defmock(App.Payments.AdapterMock, for: App.Payments.Adapter)
Mox.defmock(App.Live.AdapterMock, for: App.Live.Adapter)

ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(App.Repo, :manual)
