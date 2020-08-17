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
    conn =
      conn
      |> assign(
        :span_id,
        nil
      )
      |> assign(
        :trace_id,
        determine_trace_id(conn)
      )
      |> assign(
        :parent_id,
        determine_parent_id(conn)
      )
      |> assign(
        :span_id,
        # always set afterwards so as to accomodate the initial parent_id,
        # which should be nil
        random_span_id()
      )

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
        caller: opts.caller,
        traceId: conn.assigns[:trace_id],
        id: conn.assigns[:span_id],
        parentId: conn.assigns[:parent_id],
        user_id: conn.assigns[:current_user][:user_id],
        route: conn.assigns[:request_path],
        serviceName: opts.service_name,
        name: opts.service_name
        # when applicable, add durationMs
        # ---
        # Does not appear important in the honeycomb.ui, leaving off
        #
        # name: "http_request",
        #
        # This is incorrect, but do not know how to programatically assign based on
        # type.  My intuation is we would create a different build_ for that
        # application.
        #
        # kind: "span_event"
      }
    }
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
      |> List.first() || UUID.uuid4()
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
end
