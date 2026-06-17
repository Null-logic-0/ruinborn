defmodule Ruinborn.MatchServer do
  @moduledoc """
  GenServer wrapper around a single Ruinborn match.

  A match server owns one `Ruinborn.Match.State` process state, registers itself
  by match ID, starts countdown timers when two players are ready, delegates
  combat to `Ruinborn.Match.Combat`, and broadcasts lifecycle events through
  `Ruinborn.PubSub`.
  """

  use GenServer, restart: :transient
  require Logger

  alias Ruinborn.Match.{State, Combat}

  # Client API

  @doc """
  Starts a match process registered under `match_id`.
  """
  def start_link(match_id),
    do: GenServer.start_link(__MODULE__, match_id, name: via(match_id))

  @doc """
  Adds `player_id` to the registered match.

  When the second player joins from a startable phase, the match enters
  countdown and a countdown timer is scheduled.
  """
  def player_joined(match_id, player_id),
    do: GenServer.call(via(match_id), {:player_joined, player_id})

  @doc """
  Removes `player_id` from the registered match.

  If fewer than two players remain, the match state returns to `:waiting`.
  """
  def player_left(match_id, player_id),
    do: GenServer.call(via(match_id), {:player_left, player_id})

  @doc """
  Updates a player's position asynchronously.

  Position maps are passed through to `Ruinborn.Match.State.update_position/3`.
  """
  def update_position(match_id, player_id, pos),
    do: GenServer.cast(via(match_id), {:update_position, player_id, pos})

  @doc """
  Resolves an attack for the registered match.

  Returns `{:hit, target_id, new_hp}` on hit or `{:miss, reason}` on miss. If a
  hit reduces the target to zero HP, the server marks the match as `:ended` and
  broadcasts a `match_ended` event.
  """
  def process_attack(match_id, attacker_id, attacker_pos, weapon),
    do: GenServer.call(via(match_id), {:process_attack, attacker_id, attacker_pos, weapon})

  @doc """
  Returns the current `Ruinborn.Match.State` for `match_id`.
  """
  def get_state(match_id),
    do: GenServer.call(via(match_id), :get_state)

  # Callbacks

  @doc false
  @impl true
  def init(match_id) do
    Logger.info("MatchServer started for match: #{match_id}")
    {:ok, State.new(match_id)}
  end

  @doc false
  @impl true
  def handle_call({:player_joined, player_id}, _from, state) do
    case State.add_player(state, player_id) do
      {:error, :room_full} ->
        Logger.info(
          "Room full — rejected #{player_id}. Current players: #{inspect(Map.keys(state.players))}"
        )

        {:reply, {:error, :room_full}, state}

      {:ok, new_state} ->
        Logger.info(
          "Player #{player_id} joined match #{state.match_id}. Total players: #{map_size(new_state.players)}"
        )

        new_state =
          if State.ready_to_start?(new_state) do
            Logger.info("Match #{state.match_id} — 2 players ready, starting countdown")
            Process.send_after(self(), :countdown_tick, 1000)
            broadcast(state.match_id, "match_state", %{phase: "countdown", seconds: 3})
            %{new_state | phase: :countdown, countdown: 3}
          else
            new_state
          end

        {:reply, {:ok, new_state}, new_state}
    end
  end

  @doc false
  @impl true
  def handle_call({:player_left, player_id}, _from, state) do
    {:ok, new_state} = State.remove_player(state, player_id)

    Logger.info(
      "Player #{player_id} left match #{state.match_id}. Remaining: #{map_size(new_state.players)}"
    )

    {:reply, {:ok, new_state}, new_state}
  end

  @doc false
  @impl true
  def handle_call({:process_attack, attacker_id, attacker_pos, weapon}, _from, state) do
    case Combat.process_attack(state, attacker_id, attacker_pos, weapon) do
      {:miss, reason} ->
        {:reply, {:miss, reason}, state}

      {:hit, target_id, new_hp, damage, new_state} ->
        Logger.info(
          "#{attacker_id} hit #{target_id} --- weapon: #{weapon}, damage: #{damage}, hp: #{new_hp}"
        )

        new_state =
          if new_hp <= 0 do
            Logger.info("Match #{state.match_id} ended — winner: #{attacker_id}")

            broadcast(state.match_id, "match_ended", %{
              winner_id: attacker_id,
              loser_id: target_id
            })

            %{new_state | phase: :ended}
          else
            new_state
          end

        {:reply, {:hit, target_id, new_hp}, new_state}
    end
  end

  @doc false
  @impl true
  def handle_call(:get_state, _from, state),
    do: {:reply, state, state}

  @doc false
  @impl true
  def handle_cast({:update_position, player_id, pos}, state),
    do: {:noreply, State.update_position(state, player_id, pos)}

  @doc false
  @impl true
  def handle_info(:countdown_tick, %{phase: :countdown} = state) do
    broadcast(state.match_id, "countdown", %{seconds: state.countdown})

    if state.countdown <= 1 do
      Logger.info("Match #{state.match_id} — FIGHT!")
      broadcast(state.match_id, "match_start", %{})
      {:noreply, %{state | phase: :active, countdown: 0}}
    else
      Process.send_after(self(), :countdown_tick, 1000)
      {:noreply, %{state | countdown: state.countdown - 1}}
    end
  end

  @doc false
  def handle_info(:countdown_tick, state), do: {:noreply, state}

  # Private

  defp broadcast(match_id, event, payload) do
    Phoenix.PubSub.broadcast(
      Ruinborn.PubSub,
      "match_events:#{match_id}",
      {:match_event, event, payload}
    )
  end

  defp via(match_id),
    do: {:via, Registry, {Ruinborn.MatchRegistry, match_id}}
end
