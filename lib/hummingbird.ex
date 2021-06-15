defmodule Hummingbird do
  @moduledoc """
  A plug for shipping events to honeycomb for tracing.

  Assumes that incoming requests use the b3 propagation headers.

  Add it to your endpoint:

      defmodule MyAppWeb.Endpoint do
        use Phoenix.Endpoint, otp_app: :my_app

        plug Hummingbird

  or under a branch of your router.

  Add the telemetry genserver to your application:

      children = [
        ..
        Hummingbird.Telemetry,
        ..
      ]
  """

  use Plug.Builder

  alias Opencensus.Honeycomb.Event
  alias Hummingbird.Impl

  @sender Application.get_env(:hummingbird, :sender, Hummingbird.Sender)

  @doc false
  def init(opts), do: Keyword.take(opts, [:service_name])

  @doc false
  def call(conn, opts) do
    conn |> put_private(:hummingbird, trace_info_from_conn(conn, opts))
  end

  defp trace_info_from_conn(conn, opts) do
    %{
      trace_id: Impl.trace_id(conn),
      parent_id: Impl.parent_id(conn),
      span_id: Impl.span_id(conn),
      span_start: Event.now(),
      sample?: Impl.sampling_state(conn),
      service_name: Keyword.get(opts, :service_name),
      events: []
    }
  end

  @doc false
  def send_spans(conn) do
    with {:ok, hummingbird} <- Map.fetch(conn.private, :hummingbird),
         true <- hummingbird.sample? do
      [build_generic_honeycomb_event(conn) | conn.private.hummingbird.events]
      |> @sender.send_batch()
    else
      _ -> :ok
    end

    conn
  end

  @doc false
  # Wraps the conn in what honeycomb craves for beeeeee processing
  # Many things are in the conn and duplicated here.  The reason is by normalizing
  # the output here, we can tell honeycomb to always look in the same place for
  # user events. They don't (afaik) have an easy ability to translate different
  # shapes of events on their side

  # For example:  `booked_by:` is a different actor location than the assigns for
  # a conn.
  def build_generic_honeycomb_event(%{private: %{hummingbird: hummingbird}} = conn) do
    %Event{
      time: hummingbird.span_start,
      samplerate: 1,
      data: %{
        conn: Impl.sanitize(conn),
        component: "app",
        name: Impl.endpoint_name(conn),
        traceId: hummingbird.trace_id,
        id: hummingbird.span_id,
        parentId: hummingbird.parent_id,
        user_id: conn.assigns[:current_user][:user_id],
        serviceName: hummingbird.service_name,
        durationMs: Impl.convert_time_unit(conn.assigns[:request_duration_native]),
        http: Impl.http_metadata_from_conn(conn)
        # This is incorrect, but do not know how to programatically assign based on
        # type.  My intuation is we would create a different build_ for that
        # application.
        #
        # kind: "span_event"
      }
    }
  end

  def build_generic_honeycomb_event(_conn), do: nil

  @doc """
  Produces a random span ID.

  Produces a string of lowercase hex-encoded characters of length 16 by
  default.
  """
  def random_span_id(length \\ 16) do
    length
    |> :crypto.strong_rand_bytes()
    |> Base.encode16()
    |> binary_part(0, length)
    |> String.downcase()
  end

  @doc """
  Produces a random trace ID.

  Follows the same generation rules as a span ID, but 32 characters are used
  instead of 16.
  """
  def random_trace_id, do: random_span_id(32)

  @doc """
  Produces a list of headers for trace propagation given a conn
  """
  def propagation_headers(conn) do
    [
      {"x-b3-traceid", Impl.trace_id(conn)},
      {"x-b3-parentid", get_in(conn.private, [:hummingbird, :parent_id])},
      {"x-b3-spanid", Impl.span_id(conn)},
      {"x-b3-sampled", Impl.sampling_state_to_header_value(conn)}
    ]
    |> Enum.reject(fn {_k, v} -> v |> is_nil end)
  end
end
