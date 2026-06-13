defmodule RuinbornWeb.UserSocket do
  use Phoenix.Socket

  channel "match:*", RuinbornWeb.MatchChannel

  @impl true
  def connect(%{"player_id" => player_id}, socket, _connect_info) do
    socket = assign(socket, :player_id, player_id)
    {:ok, socket}
  end

  def connect(_params, _socket, _connect_info) do
    {:error, :missing_player_id}
  end

  @impl true
  def id(socket), do: "user_socket:#{socket.assigns.player_id}"
end
