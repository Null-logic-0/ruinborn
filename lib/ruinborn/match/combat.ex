defmodule Ruinborn.Match.Combat do
  @moduledoc """
  Combat rules for a Ruinborn match.

  This module resolves attacks against match state without broadcasting or
  mutating processes. It calculates weapon range, weapon damage, target
  distance, and the resulting HP/alive state for the target.
  """

  @doc """
  Resolves an attack from `attacker_id`.

  Attacks only resolve while the match is `:active`. The first alive opponent
  in the players map is selected as the target. If the target is within the
  selected weapon's range, the returned state includes reduced target HP and an
  updated `alive` flag.

  Returns one of:

  - `{:hit, target_id, new_hp, damage, new_state}`
  - `{:miss, :match_not_active}`
  - `{:miss, :no_target}`
  - `{:miss, :out_of_range}`
  """
  def process_attack(state, attacker_id, attacker_pos, weapon) do
    if state.phase != :active do
      {:miss, :match_not_active}
    else
      target =
        Enum.find(state.players, fn {id, p} ->
          id != attacker_id && p.alive
        end)

      case target do
        nil ->
          {:miss, :no_target}

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

            {:hit, target_id, new_hp, damage, %{state | players: updated_players}}
          else
            {:miss, :out_of_range}
          end
      end
    end
  end

  @doc """
  Returns the reach for a weapon ID.

  Weapon `0` has a range of `2.5`, weapon `1` has a range of `3.0`, and unknown
  weapons fall back to `2.5`.
  """
  def weapon_range(0), do: 2.5
  def weapon_range(1), do: 3.0
  def weapon_range(_), do: 2.5

  @doc """
  Returns the damage for a weapon ID.

  Weapon `0` deals `25`, weapon `1` deals `20`, and unknown weapons fall back
  to `20`.
  """
  def weapon_damage(0), do: 25
  def weapon_damage(1), do: 20
  def weapon_damage(_), do: 20

  @doc """
  Calculates distance between two positions on the x/z plane.

  The y-axis is ignored so attack reach is measured horizontally.
  """
  def calc_distance(%{"x" => x1, "z" => z1}, %{"x" => x2, "z" => z2}) do
    :math.sqrt(:math.pow(x2 - x1, 2) + :math.pow(z2 - z1, 2))
  end
end
