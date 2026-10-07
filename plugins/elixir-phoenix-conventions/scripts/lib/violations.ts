// plugins/elixir-phoenix-conventions/scripts/lib/violations.ts
export interface Violation {
  id: string;
  /** New files, written whole. */
  files?: { path: string; content: string }[];
  /** Changes to generated files; `find` must occur in the file. */
  edits?: { path: string; find: string; replace: string }[];
  /** Compile once before `mix precommit`, so the violation is already in _build. */
  precompile?: boolean;
  /** What `mix precommit`'s output must contain when it fails. */
  expect: RegExp;
}

const unsafeRoute = {
  path: "lib/verify_app_web/router.ex",
  find: `get "/", PageController, :home`,
  replace: `get "/", PageController, :home\n    get "/unsafe", UnsafeController, :show`,
};

const unsafeController = {
  path: "lib/verify_app_web/controllers/unsafe_controller.ex",
  content: `defmodule VerifyAppWeb.UnsafeController do
  use VerifyAppWeb, :controller

  def show(conn, %{"html" => html}) do
    render(conn, :show, html: html)
  end
end
`,
};

export const VIOLATIONS: Violation[] = [
  {
    id: "raw-in-heex-file",
    edits: [unsafeRoute],
    files: [
      unsafeController,
      {
        path: "lib/verify_app_web/controllers/unsafe_html.ex",
        content: `defmodule VerifyAppWeb.UnsafeHTML do
  use VerifyAppWeb, :html

  embed_templates "unsafe_html/*"
end
`,
      },
      { path: "lib/verify_app_web/controllers/unsafe_html/show.html.heex", content: "<div>{raw(@html)}</div>\n" },
    ],
    expect: /XSS\.Raw/,
  },
  {
    id: "raw-in-inline-heex",
    edits: [unsafeRoute],
    files: [
      unsafeController,
      {
        path: "lib/verify_app_web/controllers/unsafe_html.ex",
        content: `defmodule VerifyAppWeb.UnsafeHTML do
  use VerifyAppWeb, :html

  def show(assigns) do
    ~H"""
    <div>{raw(@html)}</div>
    """
  end
end
`,
      },
    ],
    expect: /XSS\.Raw|raw\/1 inside ~H/,
  },
  {
    id: "unmanaged-task",
    files: [{
      path: "lib/verify_app/fire.ex",
      content: `defmodule VerifyApp.Fire do
  @moduledoc false

  def fire(fun), do: Task.start(fun)
end
`,
    }],
    expect: /Task\.Supervisor\.async_nolink/,
  },
  {
    id: "case-true-false",
    files: [{
      path: "lib/verify_app/flags.ex",
      content: `defmodule VerifyApp.Flags do
  @moduledoc false

  def label(enabled?) do
    case enabled? do
      true -> "on"
      false -> "off"
    end
  end
end
`,
    }],
    expect: /case. on .true.\/.false./,
  },
  {
    id: "swallowed-rescue",
    files: [{
      path: "lib/verify_app/safe.ex",
      content: `defmodule VerifyApp.Safe do
  @moduledoc false

  def run(fun) do
    try do
      fun.()
    rescue
      _ -> :error
    end
  end
end
`,
    }],
    expect: /Rescue clause swallows exception/,
  },
  {
    id: "test-without-assertion",
    files: [{
      path: "test/verify_app/empty_test.exs",
      content: `defmodule VerifyApp.EmptyTest do
  use ExUnit.Case, async: true

  test "adds" do
    _ = 1 + 1
  end
end
`,
    }],
    expect: /This test has no assertions/,
  },
  {
    id: "open-browser",
    files: [{
      path: "test/verify_app_web/browser_test.exs",
      content: `defmodule VerifyAppWeb.BrowserTest do
  use VerifyAppWeb.ConnCase, async: true

  import PhoenixTest

  test "home page", %{conn: conn} do
    conn
    |> visit("/")
    |> open_browser()
    |> assert_has("body")
  end
end
`,
    }],
    expect: /no .open_browser. calls/,
  },
  {
    id: "unsafe-migration",
    files: [{
      path: "priv/repo/migrations/29990101000000_add_unsafe_index.exs",
      content: `defmodule VerifyApp.Repo.Migrations.AddUnsafeIndex do
  use Ecto.Migration

  def change do
    create index(:users, [:email])
  end
end
`,
    }],
    expect: /not concurrently/i,
  },
  {
    id: "compile-connected",
    files: [
      {
        path: "lib/verify_app/defaults.ex",
        content: `defmodule VerifyApp.Defaults do
  @moduledoc false

  @max VerifyApp.Settings.value()

  def max, do: @max
end
`,
      },
      {
        path: "lib/verify_app/settings.ex",
        content: `defmodule VerifyApp.Settings do
  @moduledoc false

  def value, do: VerifyApp.Base.value()
end
`,
      },
      {
        path: "lib/verify_app/base.ex",
        content: `defmodule VerifyApp.Base do
  @moduledoc false

  def value, do: 10
end
`,
      },
    ],
    expect: /Too many references/,
  },
  {
    id: "boundary-violation",
    files: [
      {
        path: "lib/verify_app/secret.ex",
        content: `defmodule VerifyApp.Secret do
  @moduledoc false

  def value, do: 42
end
`,
      },
      {
        path: "lib/verify_app_web/leak.ex",
        content: `defmodule VerifyAppWeb.Leak do
  @moduledoc false

  def value, do: VerifyApp.Secret.value()
end
`,
      },
    ],
    expect: /forbidden reference to VerifyApp\.Secret/,
  },
  {
    id: "dialyzer-contract",
    files: [{
      path: "lib/verify_app/typed.ex",
      content: `defmodule VerifyApp.Typed do
  @moduledoc false

  @spec double(integer()) :: integer()
  def double(x), do: Integer.to_string(x * 2)
end
`,
    }],
    expect: /Invalid type specification|invalid_contract|success typing/,
  },
  {
    id: "doc-reference",
    files: [{
      path: "lib/verify_app/docs_demo.ex",
      content: `defmodule VerifyApp.DocsDemo do
  @moduledoc "Delegates to \`VerifyApp.Repo.nope/0\`."

  def ok, do: :ok
end
`,
    }],
    expect: /VerifyApp\.Repo\.nope\/0/,
  },
  {
    id: "compile-warning-cached",
    precompile: true,
    files: [{
      path: "lib/verify_app/stale.ex",
      content: `defmodule VerifyApp.Stale do
  @moduledoc false

  def value do
    unused = 1
    2
  end
end
`,
    }],
    expect: /variable "unused" is unused/,
  },
  {
    id: "test-warning",
    files: [{
      path: "test/verify_app/warning_test.exs",
      content: `defmodule VerifyApp.WarningTest do
  use ExUnit.Case, async: true

  test "uses Postgres" do
    unused = 1
    assert VerifyApp.Repo.__adapter__() == Ecto.Adapters.Postgres
  end
end
`,
    }],
    expect: /variable "unused" is unused/,
  },
];
