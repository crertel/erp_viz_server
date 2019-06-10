defmodule ErpVizServerTest do
  use ExUnit.Case
  doctest ErpVizServer

  test "greets the world" do
    assert ErpVizServer.hello() == :world
  end
end
