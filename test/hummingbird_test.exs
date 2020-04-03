defmodule HummingbirdTest do
  use ExUnit.Case
  use Plug.Test
  doctest Hummingbird

  setup do
    [
      opts: %{caller: FicticiousModuleShippingEvents, service_name: "example_service"}
    ]
  end

  describe "given no request-from-trace-id header," do
    setup do
      [
        conn_without_header: conn(:get, "/foo")
      ]
    end

    test "call/2 returns conn with new trace_id",
         c do
      actual_conn = Hummingbird.call(c.conn_without_header, c.opts)

      assert not is_nil(actual_conn.assigns.trace_id)
      assert not is_nil(actual_conn.assigns.span_id)
    end
  end

  describe "given no request-from-span-id header," do
    setup do
      [
        conn_without_header: conn(:get, "/foo")
      ]
    end

    test "call/2 returns conn with no parent_id",
         c do
      actual_conn = Hummingbird.call(c.conn_without_header, c.opts)

      assert not is_nil(actual_conn.assigns.trace_id)
      assert not is_nil(actual_conn.assigns.span_id)

      assert is_nil(actual_conn.assigns.parent_id)
    end
  end

  describe "given a conn with request-from-trace-id header," do
    setup do
      expected_id = UUID.uuid4()

      [
        expected_id: expected_id,
        conn_with_header:
          conn(:get, "/foo")
          |> put_req_header("request-from-trace-id", expected_id)
      ]
    end

    test "call/2 returns conn with trace, parent, and span ids in assigns, with trace id passing through",
         c do
      actual_conn = Hummingbird.call(c.conn_with_header, c.opts)

      assert actual_conn.assigns.trace_id === c.expected_id
      assert not is_nil(actual_conn.assigns.span_id)
    end
  end

  describe "given a conn with nil trace id and no request-from-trace-id header," do
    setup do
      expected_id = UUID.uuid4()

      [
        expected_id: expected_id,
        conn_with_header: conn(:get, "/foo")
      ]
    end

    test "call/2 returns conn with new trace, and span ids in assigns and no parent",
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
          |> put_req_header("request-from-span-id", expected_id)
      ]
    end

    test "call/2 returns conn with trace, parent, and span ids in assigns, with parent id matching original span",
         c do
      actual_conn = Hummingbird.call(c.conn_with_header, c.opts)

      assert actual_conn.assigns.parent_id === c.expected_id
      assert not is_nil(actual_conn.assigns.trace_id)
      assert not is_nil(actual_conn.assigns.span_id)
    end
  end

  describe "when calling init with the caller defined," do
    test "init/1 passes only the caller attribute" do
      actual_opts = Hummingbird.init(moo: :foo, caller: "thisthing", service_name: "yourservice")

      assert actual_opts === %{caller: "thisthing", service_name: "yourservice"}
    end
  end
end
