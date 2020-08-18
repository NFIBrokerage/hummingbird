# coveralls-ignore-start
defmodule Hummingbird.Sender.Behaviour do
  @moduledoc false

  @callback send_batch(events :: [Opencensus.Honeycomb.Event.t()]) ::
              {:ok, integer()} | {:error, Exception.t()}
end

defmodule Hummingbird.Sender do
  @moduledoc false

  @behaviour __MODULE__.Behaviour

  @impl __MODULE__.Behaviour
  defdelegate send_batch(events), to: Opencensus.Honeycomb.Sender
end

# coveralls-ignore-stop
