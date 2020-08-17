defmodule HummingbirdTest do
  use ExUnit.Case
  use Plug.Test
  doctest Hummingbird

  setup do
    [
      opts: %{caller: FicticiousModuleShippingEvents, service_name: "example_service"}
    ]
  end

  describe "given no x-b3-traceid header," do
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

  describe "given no x-b3-spanid header," do
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

  describe "given a conn with x-b3-traceid header," do
    setup do
      expected_id = UUID.uuid4()

      [
        expected_id: expected_id,
        conn_with_header:
          conn(:get, "/foo")
          |> put_req_header("x-b3-traceid", expected_id)
      ]
    end

    test "call/2 returns conn with trace, parent, and span ids in assigns, with trace id passing through",
         c do
      actual_conn = Hummingbird.call(c.conn_with_header, c.opts)

      assert actual_conn.assigns.trace_id === c.expected_id
      assert not is_nil(actual_conn.assigns.span_id)
    end
  end

  describe "given a conn with nil trace id and no x-b3-traceid header," do
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

  describe "given a conn with x-b3-spanid header," do
    setup do
      expected_id = UUID.uuid4()

      [
        expected_id: expected_id,
        conn_with_header:
          conn(:get, "/foo")
          |> put_req_header("x-b3-spanid", expected_id)
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

  describe "given a conn with no x-b3-spanid header," do
    setup do
      [
        conn_without_header: conn(:get, "/foo")
      ]
    end

    test "and no parent_id already exists in conn, call/2 does not presume to know the parent_id",
         c do
      actual_conn = Hummingbird.call(c.conn_without_header, c.opts)

      assert actual_conn.assigns.parent_id === nil
      assert not is_nil(actual_conn.assigns.trace_id)
      assert not is_nil(actual_conn.assigns.span_id)
    end
  end

  describe "given conn attributes have been set, and headers have been set" do
    setup do
      expected_trace_id = "stable_trace_id"
      expected_parent_id = "previous_span_id_from_previous_plug_call"

      [
        expected_trace_id: expected_trace_id,
        expected_parent_id: expected_parent_id,
        fully_loaded_conn:
          conn(:get, "/foo")
          |> assign(:span_id, expected_parent_id)
          |> assign(:trace_id, expected_trace_id)
          |> assign(:parent_id, UUID.uuid4())
          |> put_req_header("x-b3-spanid", UUID.uuid4())
          |> put_req_header("x-b3-traceid", UUID.uuid4())
      ]
    end

    test "parent and trace ids are not overwritten by header", c do
      actual_conn = Hummingbird.call(c.fully_loaded_conn, c.opts)

      assert actual_conn.assigns.parent_id === c.expected_parent_id
      assert actual_conn.assigns.trace_id === c.expected_trace_id
      assert not is_nil(actual_conn.assigns.span_id)
    end
  end

  describe "when calling init with the caller defined," do
    test "init/1 passes only the caller attribute" do
      actual_opts = Hummingbird.init(moo: :foo, caller: "thisthing", service_name: "yourservice")

      assert actual_opts === %{caller: "thisthing", service_name: "yourservice"}
    end
  end

  test "random_span_id/0 only returns a string of downcase letters and numbers" do
    for _n <- 1..100 do
      assert Regex.match?(~r/^[a-z0-9]{16}$/, Hummingbird.random_span_id())
    end
  end
end
