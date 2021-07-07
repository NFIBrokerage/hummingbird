defmodule Hummingbird.Telemetry do
  @moduledoc """
  A handler for telemetry events which captures phoenix endpoint completions
  and ships trace information to honeycomb.

  Add it to your application children list:

      children = [
        ..
        Hummingbird.Telemetry,
        ..
      ]
  """

  use Task

  require Logger

  @doc false
  def start_link(_args) do
    Task.start_link(__MODULE__, :attach, [])
  end

  @doc false
  def attach do
    :telemetry.attach(
      "hummingbird-phoenix-endpoint-handler",
      [:phoenix, :endpoint, :stop],
      &handle_event/4,
      []
    )
  end

  @doc false
  def handle_event(
        [:phoenix, :endpoint, :stop],
        %{duration: duration_native},
        %{conn: conn},
        state
      ) do
    conn
    |> Plug.Conn.assign(:request_duration_native, duration_native)
    |> Hummingbird.send_spans()

    state
  end
end
