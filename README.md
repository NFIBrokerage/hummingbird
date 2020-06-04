# Hummingbird
A plug to correlate events between services in two lines of Elixir.

Given appropriate trace headers, ships an event for router and response calls.

**This library is under active development**

## To Use
```elixir
defmodule YourAppWeb.YourController do
  use YourAppWeb, :controller

  plug(Hummingbird, caller: __MODULE__, service_name: "your_service_name")
end
```

## Configuration
**Configure OpenCensus**
In your config.exs:
```elixir
# configure opencensus
config :opencensus,
  reporters: [{Opencensus.Honeycomb.Reporter, []}],
  send_interval_ms: 1000
```
**Set the dataset per environment**
In your dev, prod, exs files:

```elixir
# configure write key per dataset/environment
# we use environment variables to protect the secret. It doesn't matter how you
# set the value.  Choose your own adventure.

config :opencensus_honeycomb,
  dataset: "your_dataset_name_goes_here",
  write_key: "${HONEYCOMB_WRITE_KEY}"
```

## Assumptions
Currently, it looks for `x-b3-spanid` and `x-b3-traceid` headers on incoming request to create the trace.


## Proof

![Image of Trace Waterfall](images/waterfall.png)
