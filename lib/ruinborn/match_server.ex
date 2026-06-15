defmodule Ruinborn.MatchServer do
  use GenServer, restart: :transient
  require Logger

  defstruct match_id: nil,
            phase: :waiting,
            players: %{},
            countdown: 0

  # Client API

  def start_link(match_id) do
    GenServer.start_link(__MODULE__, match_id, name: via(match_id))
  end

  def player_joined(match_id, player_id) do
    GenServer.call(via(match_id), {:player_joined, player_id})
  end

  def player_left(match_id, player_id) do
    GenServer.call(via(match_id), {:player_left, player_id})
  end

  def update_position(match_id, player_id, pos) do
    GenServer.cast(via(match_id), {:update_position, player_id, pos})
  end

  def process_attack(match_id, attacker_id, attacker_pos, weapon) do
    GenServer.call(via(match_id), {:process_attack, attacker_id, attacker_pos, weapon})
  end

  def get_state(match_id), do: GenServer.call(via(match_id), :get_state)

  # Callbacks

  @impl true
  def init(match_id) do
    Logger.info("MatchServer started for match: #{match_id}")
    {:ok, %__MODULE__{match_id: match_id}}
  end

  @impl true
  def handle_call({:player_joined, player_id}, _from, state) do
    other_players = Map.delete(state.players, player_id)

    if map_size(other_players) >= 2 do
      Logger.info(
        "Room full — rejected #{player_id}. Current players: #{inspect(Map.keys(state.players))}"
      )

      {:reply, {:error, :room_full}, state}
    else
      updated_players =
        Map.put(state.players, player_id, %{
          hp: 100,
          alive: true,
          pos: %{"x" => 0, "y" => 0, "z" => 0}
        })

      new_state = %{state | players: updated_players}

      Logger.info(
        "Player #{player_id} joined match #{state.match_id}. " <>
          "Total players: #{map_size(updated_players)}"
      )

      new_state =
        if map_size(updated_players) == 2 && state.phase in [:waiting, :ended] do
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

  @impl true
  def handle_call({:player_left, player_id}, _from, state) do
    updated_players = Map.delete(state.players, player_id)
    remaining = map_size(updated_players)

    Logger.info(
      "Player #{player_id} left match #{state.match_id}. " <>
        "Remaining players: #{remaining}"
    )

    new_state =
      if remaining < 2 do
        %{state | players: updated_players, phase: :waiting, countdown: 0}
      else
        %{state | players: updated_players}
      end

    {:reply, {:ok, new_state}, new_state}
  end

  @impl true
  def handle_call({:process_attack, attacker_id, attacker_pos, weapon}, _from, state) do
    # Block attacks unless match is active
    if state.phase != :active do
      {:reply, {:miss, :match_not_active}, state}
    else
      target =
        Enum.find(state.players, fn {id, p} ->
          id != attacker_id && p.alive
        end)

      case target do
        nil ->
          {:reply, {:miss, :no_target}, state}

        {target_id, target_state} ->
          distance = calc_distance(attacker_pos, target_state.pos)
          range = weapon_range(weapon)

          if distance <= range do
            damage = weapon_damage(weapon)
            new_hp = max(0, target_state.hp - damage)
            new_alive = new_hp > 0

            updated_players =
              Map.update!(state.players, target_id, fn p ->
                %{p | hp: new_hp, alive: new_alive}
              end)

            new_state = %{state | players: updated_players}

            Logger.info(
              "#{attacker_id} hit #{target_id} --- " <>
                "weapon: #{weapon}, damage: #{damage}, hp: #{new_hp}"
            )

            # If player died -> end the match
            new_state =
              if !new_alive do
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
          else
            Logger.debug("Miss --- distance: #{distance}, range: #{range}")
            {:reply, {:miss, :out_of_range}, state}
          end
      end
    end
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_cast({:update_position, player_id, pos}, state) do
    updated =
      Map.update(state.players, player_id, %{}, fn p ->
        %{p | pos: pos}
      end)

    {:noreply, %{state | players: updated}}
  end

  # Countdown ticker
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

  def handle_info(:countdown_tick, state), do: {:noreply, state}

  # Private Helpers

  defp weapon_range(0), do: 2.5
  defp weapon_range(1), do: 3.0
  defp weapon_range(_), do: 2.5

  defp weapon_damage(0), do: 25
  defp weapon_damage(1), do: 20
  defp weapon_damage(_), do: 20

  defp calc_distance(%{"x" => x1, "z" => z1}, %{"x" => x2, "z" => z2}) do
    :math.sqrt(:math.pow(x2 - x1, 2) + :math.pow(z2 - z1, 2))
  end

  defp broadcast(match_id, event, payload) do
    Phoenix.PubSub.broadcast(
      Ruinborn.PubSub,
      "match_events:#{match_id}",
      {:match_event, event, payload}
    )
  end

  defp via(match_id) do
    {:via, Registry, {Ruinborn.MatchRegistry, match_id}}
  end
end
