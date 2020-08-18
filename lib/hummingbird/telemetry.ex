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

  use GenServer

  require Logger

  @doc false
  def start_link(_args) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @doc false
  def init(state) do
    {:ok, state, {:continue, :telemetry_attach}}
  end

  @doc false
  def handle_continue(:telemetry_attach, state) do
    :telemetry.attach(
      "hummingbird-phoenix-endpoint-handler",
      [:phoenix, :endpoint, :stop],
      &handle_event/4,
      []
    )

    {:noreply, state}
  end

  @doc false
  def handle_event(
        [:phoenix, :endpoint, :stop],
        %{duration: duration_native},
        %{conn: conn},
        _config
      ) do
    GenServer.cast(__MODULE__, {conn, duration_native})
  end

  @doc false
  def handle_cast({conn, duration_native}, state) do
    conn
    |> Plug.Conn.assign(:request_duration_native, duration_native)
    |> Hummingbird.send_spans()

    {:noreply, state}
  end
end
