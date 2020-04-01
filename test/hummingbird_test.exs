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

    test "call/2 returns conn with trace, parent, and span ids in assigns, with trace id passing through",
         c do
      actual_conn = Hummingbird.call(c.conn_with_header, c.opts)

      assert actual_conn.assigns.trace_id === c.expected_id
      assert Map.has_key?(actual_conn.assigns, :span_id)
      assert not is_nil(actual_conn.assigns.span_id)
    end
  end

  describe "given a conn with nil trace id and no request-from-trace-id header," do
    setup do
      expected_id = UUID.uuid4()

      [
        expected_id: expected_id,
        conn_with_header:
          conn(:get, "/foo")
          |> assign(:trace_id, nil),
        # |> put_req_header("request-from-trace-id", expected_id)
        opts: %{caller: FicticiousModuleShippingEvents}
      ]
    end

    test "call/2 returns conn with trace, parent, and span ids in assigns, with trace id passing through",
         c do
      actual_conn = Hummingbird.call(c.conn_with_header, c.opts)

      assert not is_nil(actual_conn.assigns.trace_id)
      assert is_nil(actual_conn.assigns.parent_id)
      assert not is_nil(actual_conn.assigns.span_id)
    end
  end

  describe "given a conn with request-from-span-id header," do
    setup do
      expected_id = UUID.uuid4()

      [
        expected_id: expected_id,
        conn_with_header:
          conn(:get, "/foo")
          |> put_req_header("request-from-span-id", expected_id),
        opts: %{caller: FicticiousModuleShippingEvents}
      ]
    end

    test "call/2 returns conn with trace, parent, and span ids in assigns, with parent id matching original span",
         c do
      actual_conn = Hummingbird.call(c.conn_with_header, c.opts)

      assert actual_conn.assigns.parent_id === c.expected_id
      assert Map.has_key?(actual_conn.assigns, :trace_id)
      assert not is_nil(actual_conn.assigns.span_id)
    end
  end

  describe "when building values for honeycomb event," do
    test "sanitize/1 strips private information from the conn", c do
      assumed_conn = Hummingbird.call(c.conn_with_header, c.opts)
      assert not is_nil(assumed_conn.private)

      actual_conn = Hummingbird.sanitize(assumed_conn)
      assert actual_conn.private === nil
    end
  end
end
