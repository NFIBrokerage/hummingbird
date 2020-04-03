defmodule Hummingbird.Helpers do
  @moduledoc """
  Internal supporting functions for managing the conn and assigning trace
  information.
  """

  @doc """
  Removes private information from the conn before shipping.
  """
  def sanitize(conn) do
    %{
      conn
      | private: nil,
        secret_key_base: nil
    }
  end
end
