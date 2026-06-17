defmodule Ruinborn.Match.CombatTest do
  use ExUnit.Case, async: true

  alias Ruinborn.Match.{Combat, State}

  defp active_state(attrs \\ %{}) do
    players =
      Map.get(attrs, :players, %{
        "attacker" => %{hp: 100, alive: true, pos: %{"x" => 0, "y" => 0, "z" => 0}},
        "target" => %{hp: 100, alive: true, pos: %{"x" => 2, "y" => 0, "z" => 0}}
      })

    %State{
      match_id: "match-1",
      phase: Map.get(attrs, :phase, :active),
      players: players
    }
  end

  describe "process_attack/4" do
    test "misses when the match is not active" do
      state = active_state(%{phase: :waiting})

      assert Combat.process_attack(state, "attacker", %{"x" => 0, "z" => 0}, 0) ==
               {:miss, :match_not_active}
    end

    test "damages the first alive opponent in range" do
      state = active_state()

      assert {:hit, "target", 75, 25, new_state} =
               Combat.process_attack(state, "attacker", %{"x" => 0, "z" => 0}, 0)

      assert new_state.players["target"].hp == 75
      assert new_state.players["target"].alive == true
      assert new_state.players["attacker"].hp == 100
    end

    test "misses when the target is out of range" do
      state =
        active_state(%{
          players: %{
            "attacker" => %{hp: 100, alive: true, pos: %{"x" => 0, "y" => 0, "z" => 0}},
            "target" => %{hp: 100, alive: true, pos: %{"x" => 4, "y" => 0, "z" => 0}}
          }
        })

      assert Combat.process_attack(state, "attacker", %{"x" => 0, "z" => 0}, 0) ==
               {:miss, :out_of_range}
    end

    test "marks the target dead without dropping hp below zero" do
      state =
        active_state(%{
          players: %{
            "attacker" => %{hp: 100, alive: true, pos: %{"x" => 0, "y" => 0, "z" => 0}},
            "target" => %{hp: 20, alive: true, pos: %{"x" => 2, "y" => 0, "z" => 0}}
          }
        })

      assert {:hit, "target", 0, 25, new_state} =
               Combat.process_attack(state, "attacker", %{"x" => 0, "z" => 0}, 0)

      assert new_state.players["target"].hp == 0
      assert new_state.players["target"].alive == false
    end

    test "misses when no alive opponent exists" do
      state =
        active_state(%{
          players: %{
            "attacker" => %{hp: 100, alive: true, pos: %{"x" => 0, "y" => 0, "z" => 0}},
            "target" => %{hp: 0, alive: false, pos: %{"x" => 2, "y" => 0, "z" => 0}}
          }
        })

      assert Combat.process_attack(state, "attacker", %{"x" => 0, "z" => 0}, 0) ==
               {:miss, :no_target}
    end
  end

  describe "weapon stats" do
    test "uses configured ranges and fallback values" do
      assert Combat.weapon_range(0) == 2.5
      assert Combat.weapon_range(1) == 3.0
      assert Combat.weapon_range(99) == 2.5
    end

    test "uses configured damage and fallback values" do
      assert Combat.weapon_damage(0) == 25
      assert Combat.weapon_damage(1) == 20
      assert Combat.weapon_damage(99) == 20
    end
  end

  describe "calc_distance/2" do
    test "calculates distance on the x/z plane" do
      assert Combat.calc_distance(%{"x" => 0, "z" => 0}, %{"x" => 3, "z" => 4}) == 5.0
    end
  end
end
