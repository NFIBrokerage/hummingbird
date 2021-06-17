defmodule Hummingbird.Impl do
  @moduledoc false

  import Plug.Conn, only: [get_req_header: 2]

  # Internal supporting functions for managing the conn and assigning trace
  # information.

  # removes private information from the conn before shipping.
  def sanitize(conn) do
    %{
      conn
      | private: nil,
        secret_key_base: nil,
        assigns: Map.take(conn.assigns, [:current_user, :admin_user])
    }
  end

  # JSON encode all params fields in the conn.
  # this reduces the risk of exhausting the Honeycomb column count.
  # Honeycomb can then be configured to unpack encoded fields to configurable
  # depth if you still want structured fields/columns for these params.
  def encode_params(conn) do
    %{
      conn
      | params: encode_fetched_params(conn.params),
        body_params: encode_fetched_params(conn.body_params),
        path_params: encode_fetched_params(conn.path_params),
        query_params: encode_fetched_params(conn.query_params)
    }
  end

  defp encode_fetched_params(params) do
    case params do
      %Plug.Conn.Unfetched{} -> params
      _ -> Jason.encode!(params)
    end
  end

  def endpoint_name(conn) do
    inspect(conn.private[:phoenix_endpoint])
  end

  def parent_id(conn) do
    if get_in(conn.private, [:hummingbird, :span_id]) == nil do
      # wasn't set previously so check header
      conn
      |> get_req_header("x-b3-spanid")
      |> List.first()
    else
      conn.private.hummingbird.span_id
    end
  end

  def span_id(conn) do
    if get_in(conn.private, [:hummingbird, :span_id]) == nil do
      Hummingbird.random_span_id()
    else
      conn.private.hummingbird.span_id
    end
  end

  def trace_id(conn) do
    if get_in(conn.private, [:hummingbird, :trace_id]) == nil do
      conn
      |> get_req_header("x-b3-traceid")
      |> List.first() || Hummingbird.random_trace_id()
    else
      conn.private.hummingbird.trace_id
    end
  end

  def sampling_state(conn) do
    with nil <- get_in(conn.private, [:hummingbird, :sample?]),
         nil <- conn |> get_req_header("x-b3-sampled") |> List.first() do
      true
    else
      "1" -> true
      "0" -> false
      prior_sampling_state -> prior_sampling_state
    end
  end

  def http_metadata_from_conn(%Plug.Conn{} = conn) do
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

  def convert_time_unit(nil), do: nil

  def convert_time_unit(time) when is_integer(time) do
    System.convert_time_unit(time, :native, :microsecond) / 1000
  end

  def sampling_state_to_header_value(conn) do
    case sampling_state(conn) do
      true -> "1"
      false -> "0"
      nil -> nil
    end
  end
end
