defmodule HummingbirdTest do
  use ExUnit.Case
  use Plug.Test
  doctest Hummingbird

  import Mox

  setup :verify_on_exit!

  setup do
    [opts: [service_name: "example_service"]]
  end

  describe "given a conn with all params fields populated," do
    setup do
      path_params = %{"my_path_param_key" => "my_path_param_value"}

      conn =
        conn(:get, "/foo?my_query_param_key=my_query_param_value", %{
          my_body_param_key: "my_body_param_value"
        })
        |> Plug.Conn.fetch_query_params()
        |> Map.put(:path_params, path_params)
        |> Map.update!(:params, fn params -> Map.merge(params, path_params) end)

      [
        conn: conn
      ]
    end

    test "send_spans/1 yields honeycomb events with json encoded params fields",
         c do
      expect(SenderMock, :send_batch, 1, fn events ->
        assert [event] = events
        assert {:ok, _} = Jason.decode(event.data.conn.params)
        assert {:ok, _} = Jason.decode(event.data.conn.body_params)
        assert {:ok, _} = Jason.decode(event.data.conn.path_params)
        assert {:ok, _} = Jason.decode(event.data.conn.query_params)
      end)

      c.conn
      |> Hummingbird.call(c.opts)
      |> Hummingbird.send_spans()
    end
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

      assert not is_nil(actual_conn.private.hummingbird.trace_id)
      assert not is_nil(actual_conn.private.hummingbird.span_id)
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

      assert not is_nil(actual_conn.private.hummingbird.trace_id)
      assert not is_nil(actual_conn.private.hummingbird.span_id)

      assert is_nil(actual_conn.private.hummingbird.parent_id)
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

    test "call/2 returns conn with trace, parent, and span ids in private.hummingbird, with trace id passing through",
         c do
      actual_conn = Hummingbird.call(c.conn_with_header, c.opts)

      assert actual_conn.private.hummingbird.trace_id === c.expected_id
      assert not is_nil(actual_conn.private.hummingbird.span_id)
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

    test "call/2 returns conn with new trace, and span ids in private.hummingbird and no parent",
         c do
      actual_conn = Hummingbird.call(c.conn_with_header, c.opts)

      assert not is_nil(actual_conn.private.hummingbird.trace_id)
      assert is_nil(actual_conn.private.hummingbird.parent_id)
      assert not is_nil(actual_conn.private.hummingbird.span_id)
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

    test "call/2 returns conn with trace, parent, and span ids in private.hummingbird, with parent id matching original span",
         c do
      actual_conn = Hummingbird.call(c.conn_with_header, c.opts)

      assert actual_conn.private.hummingbird.parent_id === c.expected_id
      assert not is_nil(actual_conn.private.hummingbird.trace_id)
      assert not is_nil(actual_conn.private.hummingbird.span_id)
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

      assert actual_conn.private.hummingbird.parent_id === nil
      assert not is_nil(actual_conn.private.hummingbird.trace_id)
      assert not is_nil(actual_conn.private.hummingbird.span_id)
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
          |> put_private(:phoenix_endpoint, FooWeb.Endpoint)
          |> put_private(:hummingbird, %{
            span_id: expected_parent_id,
            trace_id: expected_trace_id,
            parent_id: UUID.uuid4(),
            sample?: true
          })
          |> put_req_header("x-b3-spanid", UUID.uuid4())
          |> put_req_header("x-b3-traceid", UUID.uuid4())
          |> put_req_header("x-b3-sampled", "0")
      ]
    end

    test "parent and trace ids are not overwritten by header", c do
      actual_conn = Hummingbird.call(c.fully_loaded_conn, c.opts)

      assert actual_conn.private.hummingbird.parent_id === c.expected_parent_id
      assert actual_conn.private.hummingbird.trace_id === c.expected_trace_id
      assert not is_nil(actual_conn.private.hummingbird.span_id)
    end

    test "propagation_headers/1 puts trace information into header format", c do
      headers = Hummingbird.propagation_headers(c.fully_loaded_conn)

      get_header = &Enum.find_value(headers, fn {k, v} -> k == &1 && v end)

      assert get_header.("x-b3-traceid") == c.expected_trace_id
      assert get_header.("x-b3-sampled") == "1"
    end

    test "emitting a telemetry event for phoenix triggers a batch send", c do
      telemetry_pid = start_supervised!(Hummingbird.Telemetry)
      self = self()

      SenderMock
      |> expect(:send_batch, 1, fn events ->
        assert [%Opencensus.Honeycomb.Event{}] = events

        send(self, :done)
      end)
      |> allow(self(), telemetry_pid)

      conn = Hummingbird.call(c.fully_loaded_conn, c.opts)

      :telemetry.execute([:phoenix, :endpoint, :stop], %{duration: 42_660_714}, %{conn: conn})

      assert_receive :done

      stop_supervised(telemetry_pid)

      :ok
    end
  end

  describe "when calling init with the caller defined," do
    test "init/1 passes only the caller attribute" do
      actual_opts = Hummingbird.init(moo: :foo, caller: "thisthing", service_name: "yourservice")

      assert actual_opts === [service_name: "yourservice"]
    end
  end

  test "random_span_id/0 only returns a string of downcase letters and numbers" do
    for _n <- 1..100 do
      assert Regex.match?(~r/^[a-z0-9]{16}$/, Hummingbird.random_span_id())
    end
  end
end
