defmodule Ruinborn.MatchServer do
  use GenServer, restart: :transient

  require Logger

  defstruct match_id: nil, phase: :waiting, players: %{}

  # ---------------------------------------------------------------------------
  # Client API
  # ---------------------------------------------------------------------------

  def start_link(match_id) do
    GenServer.start_link(__MODULE__, match_id, name: via(match_id))
  end

  def player_joined(match_id, player_id) do
    GenServer.call(via(match_id), {:player_joined, player_id})
  end

  def player_left(match_id, player_id) do
    GenServer.call(via(match_id), {:player_left, player_id})
  end

  def get_state(match_id) do
    GenServer.call(via(match_id), :get_state)
  end

  @impl true
  def init(match_id) do
    Logger.info("MatchServer started for match: #{match_id}")
    {:ok, %__MODULE__{match_id: match_id}}
  end

  @impl true
  def handle_call({:player_joined, player_id}, _from, state) do
    updated_players = Map.put(state.players, player_id, %{hp: 100, alive: true})
    new_state = %{state | players: updated_players}

    Logger.info(
      "Player #{player_id} joined match #{state.match_id}. " <>
        "Total players: #{map_size(updated_players)}"
    )

    {:reply, {:ok, new_state}, new_state}
  end

  @impl true
  def handle_call({:player_left, player_id}, _from, state) do
    updated_players = Map.delete(state.players, player_id)
    new_state = %{state | players: updated_players}

    Logger.info(
      "Player #{player_id} left match #{state.match_id}. " <>
        "Remaining players: #{map_size(updated_players)}"
    )

    {:reply, {:ok, new_state}, new_state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  defp via(match_id) do
    {:via, Registry, {Ruinborn.MatchRegistry, match_id}}
  end
end
