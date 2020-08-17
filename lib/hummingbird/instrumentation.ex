defmodule Hummingbird.Instrumentation do
  @moduledoc """
  Plug instrumentation for an endpoint which records durations
  """

  defmacro __using__(opts) do
    quote do
      # N.B. in this context, I'm saying execution to mean a run through the
      # phoenix pipeline (endpoint -> router -> controllers, etc..)
      def call(conn, opts) do
        conn_before_execution = Hummingbird.set_trace_info(conn)

        {time, conn_after_execution} = :timer.tc(fn -> super(conn_before_execution, opts) end)

        conn_after_execution
        |> assign(:request_duration, System.convert_time_unit(time, :native, :millisecond))
        |> Hummingbird.send_span(unquote(opts) |> Hummingbird.init())

        conn_after_execution
      end

      defoverridable call: 2
    end
  end
end
