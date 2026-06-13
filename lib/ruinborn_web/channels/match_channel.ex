defmodule RuinbornWeb.MatchChannel do
  use RuinbornWeb, :channel

  alias Ruinborn.MatchServer
  require Logger

  @impl true
  def join("match:" <> match_id, _payload, socket) do
    player_id = socket.assigns.player_id
    :ok = ensure_match_started(match_id)
    {:ok, match_state} = MatchServer.player_joined(match_id, player_id)

    send(self(), {:after_join, player_id, match_state})

    socket = assign(socket, :match_id, match_id)

    Logger.info("#{player_id} joined match #{match_id}")
    {:ok, socket}
  end

  @impl true
  def handle_info({:after_join, player_id, match_state}, socket) do
    broadcast!(socket, "player_joined", %{
      player_id: player_id,
      player_count: map_size(match_state.players)
    })

    {:noreply, socket}
  end

  @impl true
  def handle_in("ping", _payload, socket) do
    {:reply, {:ok, %{pong: true}}, socket}
  end

  @impl true
  def handle_in("move", %{"pos" => pos}, socket) do
    broadcast_from!(socket, "player_moved", %{
      player_id: socket.assigns.player_id,
      pos: pos
    })

    {:noreply, socket}
  end

  @impl true
  def terminate(_reason, socket) do
    match_id = socket.assigns[:match_id]
    player_id = socket.assigns[:player_id]

    if match_id && player_id do
      {:ok, new_state} = MatchServer.player_left(match_id, player_id)

      broadcast!(socket, "player_left", %{
        player_id: player_id,
        player_count: map_size(new_state.players)
      })
    end

    :ok
  end

  defp ensure_match_started(match_id) do
    case DynamicSupervisor.start_child(
           Ruinborn.MatchSupervisor,
           {MatchServer, match_id}
         ) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end
  end
end
