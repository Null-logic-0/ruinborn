defmodule Ruinborn.Match.State do
  @moduledoc """
  Pure match-state transitions.

  `Ruinborn.Match.State` owns the data shape for an in-progress match and
  provides deterministic helpers for adding players, removing players, moving
  players, and deciding whether a match can start.

  The module does not perform side effects. Process orchestration, timers, and
  broadcasts are handled by `Ruinborn.MatchServer`.
  """

  defstruct match_id: nil,
            phase: :waiting,
            players: %{},
            countdown: 0

  @doc """
  Builds a new match state for `match_id`.

  New matches start in the `:waiting` phase with no players and a zero
  countdown.
  """
  def new(match_id), do: %__MODULE__{match_id: match_id}

  @doc """
  Adds `player_id` to a match.

  New players start with 100 HP, `alive: true`, and a default position at the
  origin. A duplicate player ID replaces that player's existing state and does
  not count as a third occupant.

  Returns `{:ok, state}` on success or `{:error, :room_full}` when two other
  distinct players are already present.
  """
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

  @doc """
  Removes `player_id` from a match.

  If fewer than two players remain, the match is reset to `:waiting` and the
  countdown is cleared.
  """
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

  @doc """
  Updates `player_id` with a new position map.

  Position maps are expected to use string keys such as `"x"`, `"y"`, and
  `"z"` because they arrive from JSON channel payloads.
  """
  def update_position(%__MODULE__{} = state, player_id, pos) do
    updated = Map.update(state.players, player_id, %{}, fn p -> %{p | pos: pos} end)
    %{state | players: updated}
  end

  @doc """
  Returns whether a match has exactly two players and can enter countdown.

  Matches can start from `:waiting` or restart from `:ended`.
  """
  def ready_to_start?(%__MODULE__{} = state) do
    map_size(state.players) == 2 && state.phase in [:waiting, :ended]
  end
end
