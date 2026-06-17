defmodule Ruinborn.Match.State do
  defstruct match_id: nil,
            phase: :waiting,
            players: %{},
            countdown: 0

  def new(match_id), do: %__MODULE__{match_id: match_id}

  def add_player(%__MODULE__{} = state, player_id) do
    other_players = Map.delete(state.players, player_id)

    if map_size(other_players) >= 2 do
      {:error, :room_full}
    else
      updated =
        Map.put(state.players, player_id, %{
          hp: 100,
          alive: true,
          pos: %{"x" => 0, "y" => 0, "z" => 0}
        })

      {:ok, %{state | players: updated}}
    end
  end

  def remove_player(%__MODULE__{} = state, player_id) do
    updated = Map.delete(state.players, player_id)
    remaining = map_size(updated)

    new_state =
      if remaining < 2 do
        %{state | players: updated, phase: :waiting, countdown: 0}
      else
        %{state | players: updated}
      end

    {:ok, new_state}
  end

  def update_position(%__MODULE__{} = state, player_id, pos) do
    updated = Map.update(state.players, player_id, %{}, fn p -> %{p | pos: pos} end)
    %{state | players: updated}
  end

  def ready_to_start?(%__MODULE__{} = state) do
    map_size(state.players) == 2 && state.phase in [:waiting, :ended]
  end
end
