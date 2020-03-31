defmodule HummingbirdTest do
  use ExUnit.Case
  use Plug.Test
  doctest Hummingbird

  describe "given a conn with request-from-trace-id header," do
    setup do
      expected_id = UUID.uuid4()

      [
        expected_id: expected_id,
        conn_with_header:
          conn(:get, "/foo")
          |> put_req_header("request-from-trace-id", expected_id),
        opts: %{caller: FicticiousModuleShippingEvents}
      ]
    end

    test "call/2 returns conn with trace, parent, and span ids in assigns", c do
      assert Hummingbird.call(c.conn_with_header, c.opts) === :thisshouldfail
    end
  end
end
