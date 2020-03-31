defmodule HummingbirdTest do
  use ExUnit.Case
  doctest Hummingbird

  test "greets the world" do
    assert Hummingbird.hello() == :world
  end
end
