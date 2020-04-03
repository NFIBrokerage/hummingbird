defmodule Hummingbird.HelpersTest do
  use ExUnit.Case
  use Plug.Test

  alias Hummingbird.Helpers

  setup do
    [
      opts: %{caller: FicticiousModuleShippingEvents, service_name: "example_service"}
    ]
  end

  describe "when building values for honeycomb event," do
    test "sanitize/1 strips private information from the plug-transformed conn", c do
      assumed_conn = Hummingbird.call(conn(:get, "/foo"), c.opts)
      assert not is_nil(assumed_conn.private)

      actual_conn = Helpers.sanitize(assumed_conn)

      assert actual_conn.private === nil
      assert actual_conn.secret_key_base === nil
    end
  end
end
