defmodule RuinbornWeb.UserSocket do
  @moduledoc """
  Socket entry point for Ruinborn players.

  A client must connect with a `"player_id"` parameter. Once connected, the
  player can join `"match:*"` topics handled by `RuinbornWeb.MatchChannel`.
  """

  use Phoenix.Socket

  channel "match:*", RuinbornWeb.MatchChannel

  @doc false
  @impl true
  def connect(%{"player_id" => player_id}, socket, _connect_info) do
    socket = assign(socket, :player_id, player_id)
    {:ok, socket}
  end

  def connect(_params, _socket, _connect_info) do
    {:error, :missing_player_id}
  end

  @doc false
  @impl true
  def id(socket), do: "user_socket:#{socket.assigns.player_id}"
end
