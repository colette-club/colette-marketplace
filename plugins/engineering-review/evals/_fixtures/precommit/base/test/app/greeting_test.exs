defmodule App.GreetingTest do
  use ExUnit.Case, async: true

  describe "hello/1" do
    test "when given a name" do
      assert App.Greeting.hello("Ada") == "Hello, Ada"
    end
  end
end
