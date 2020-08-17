defmodule Hummingbird do
  @moduledoc """
  Ships the conn to honeycomb.io to allow distributed tracing.

  Assumes requests that come in populate two different headers:
  x-b3-traceid and x-b3-spanid
  """

  use Plug.Builder

  alias Opencensus.Honeycomb.{Event, Sender}
  alias Hummingbird.Helpers

  def init(opts) do
    %{
      caller: Keyword.get(opts, :caller),
      service_name: Keyword.get(opts, :service_name)
    }
  end

  @doc """
  An impure dispatching of conn information to the elixir honeycomb client
  """
  def call(conn, opts) do
    conn = set_trace_info(conn)

    send_span(conn, opts)
  end

  @doc false
  def set_trace_info(conn) do
    conn
    |> assign(:trace_id, determine_trace_id(conn))
    |> assign(:parent_id, determine_parent_id(conn))
    |> assign(:span_id, random_span_id())
  end

  @doc false
  def send_span(conn, opts) do
    [
      build_generic_honeycomb_event(conn, opts)
    ]
    |> Sender.send_batch()

    conn
  end

  @doc """
  Wraps the conn in what honeycomb craves for beeeeee processing
  Many things are in the conn and duplicated here.  The reason is by normalizing
  the output here, we can tell honeycomb to always look in the same place for
  user events. They don't (afaik) have an easy ability to translate different
  shapes of events on their side

  For example:  `booked_by:` is a different actor location than the assigns for
  a conn.

  Warning: this is a mix of translating on the way out to OpenCensus+Honeycomb
  language. Don't know enough at this moment to disambiguate the two languages.
  """
  def build_generic_honeycomb_event(conn, opts) do
    %Event{
      time: Event.now(),
      data: %{
        conn: Helpers.sanitize(conn),
        name: opts.caller,
        traceId: conn.assigns[:trace_id],
        id: conn.assigns[:span_id],
        parentId: conn.assigns[:parent_id],
        user_id: conn.assigns[:current_user][:user_id],
        route: conn.assigns[:request_path],
        serviceName: opts.service_name,
        durationMs: convert_time_unit(conn.assigns[:request_duration_native]),
        http: http_metadata_from_conn(conn)
        # This is incorrect, but do not know how to programatically assign based on
        # type.  My intuation is we would create a different build_ for that
        # application.
        #
        # kind: "span_event"
      }
    }

    # |> IO.inspect(label: :event)
  end

  @doc """
  If a span has already been created for this conn, just use that as the parent.

  If not, check the headers for a span_id to hold onto and use that as your parent_id.
  The latter occurs when taking in IDs from external contexts, read: commands.

  If neither are set, this span should not have a parent.
  """
  def determine_parent_id(conn) do
    if is_nil(conn.assigns[:span_id]) do
      # wasn't set previously so check header
      conn
      |> get_req_header("x-b3-spanid")
      |> List.first()
    else
      conn.assigns[:span_id]
    end
  end

  @doc """
  Grabs the trace id sent over from initiating request.  If nah, starts a trace
  for within this application.
  """
  def determine_trace_id(conn) do
    if is_nil(conn.assigns[:trace_id]) do
      conn
      |> get_req_header("x-b3-traceid")
      |> List.first() || random_trace_id()
    else
      # fallback to this being an internal responsibility to assign a trace id
      conn.assigns[:trace_id]
    end
  end

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

  defp http_metadata_from_conn(%Plug.Conn{} = conn) do
    scheme = Atom.to_string(conn.scheme)

    url =
      %URI{
        scheme: scheme,
        path: conn.request_path,
        port: conn.port,
        host: conn.host
      }
      |> URI.to_string()

    %{
      url: url,
      status_code: conn.status,
      method: conn.method,
      protocol: scheme
    }
  end

  # converts native time to µs to ms
  # we have to convert to µs first because System.convert_time_unit/3 will
  # round the resulting time
  defp convert_time_unit(nil), do: nil

  defp convert_time_unit(native_time) when is_integer(native_time) do
    System.convert_time_unit(native_time, :native, :microseconds) / 1000
  end
end
