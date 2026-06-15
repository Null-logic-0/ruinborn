defmodule Ruinborn.MatchServer do
  use GenServer, restart: :transient

  require Logger

  defstruct match_id: nil, phase: :waiting, players: %{}

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

  def get_state(match_id) do
    GenServer.call(via(match_id), :get_state)
  end

  # Callbacks

  @impl true
  def init(match_id) do
    Logger.info("MatchServer started for match: #{match_id}")
    {:ok, %__MODULE__{match_id: match_id}}
  end

  @impl true
  def handle_call({:player_joined, player_id}, _from, state) do
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
  def handle_call({:process_attack, attacker_id, attacker_pos, weapon}, _from, state) do
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
            "#{attacker_id} hit #{target_id} ---" <>
              "weapon: #{weapon}, damage: #{damage},hp: #{new_hp}"
          )

          {:reply, {:hit, target_id, new_hp}, new_state}
        else
          Logger.debug("Miss --- distance: #{distance}, range: #{range}")
          {:reply, {:miss, :out_of_range}, state}
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

  # Private Helpers

  # axe
  defp weapon_range(0), do: 2.5

  # bat
  defp weapon_range(1), do: 3.0

  defp weapon_range(_), do: 2.5

  # Damage per hit

  # axe
  defp weapon_damage(0), do: 25

  # bat
  defp weapon_damage(1), do: 20

  defp weapon_damage(_), do: 20

  defp calc_distance(%{"x" => x1, "z" => z1}, %{"x" => x2, "z" => z2}) do
    :math.sqrt(:math.pow(x2 - x1, 2) + :math.pow(z2 - z1, 2))
  end

  defp via(match_id) do
    {:via, Registry, {Ruinborn.MatchRegistry, match_id}}
  end
end
