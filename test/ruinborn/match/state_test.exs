defmodule Ruinborn.Match.StateTest do
  use ExUnit.Case, async: true

  alias Ruinborn.Match.State

  describe "new/1" do
    test "starts a waiting match with no players" do
      assert State.new("match-1") == %State{
               match_id: "match-1",
               phase: :waiting,
               players: %{},
               countdown: 0
             }
    end
  end

  describe "add_player/2" do
    test "adds a player with default combat state" do
      {:ok, state} =
        "match-1"
        |> State.new()
        |> State.add_player("player-1")

      assert state.players["player-1"] == %{
               hp: 100,
               alive: true,
               pos: %{"x" => 0, "y" => 0, "z" => 0}
             }
    end

    test "allows the same player to rejoin without filling the room" do
      {:ok, state} =
        "match-1"
        |> State.new()
        |> State.add_player("player-1")

      assert {:ok, state} = State.add_player(state, "player-1")
      assert map_size(state.players) == 1
    end

    test "rejects a third distinct player" do
      {:ok, state} =
        "match-1"
        |> State.new()
        |> State.add_player("player-1")

      {:ok, state} = State.add_player(state, "player-2")

      assert {:error, :room_full} = State.add_player(state, "player-3")
      assert Map.keys(state.players) |> Enum.sort() == ["player-1", "player-2"]
    end
  end

  describe "remove_player/2" do
    test "returns to waiting and clears countdown when fewer than two players remain" do
      state = %State{
        match_id: "match-1",
        phase: :countdown,
        countdown: 2,
        players: %{
          "player-1" => %{hp: 100, alive: true, pos: %{"x" => 0, "y" => 0, "z" => 0}},
          "player-2" => %{hp: 100, alive: true, pos: %{"x" => 0, "y" => 0, "z" => 0}}
        }
      }

      assert {:ok, state} = State.remove_player(state, "player-2")
      assert state.phase == :waiting
      assert state.countdown == 0
      assert Map.keys(state.players) == ["player-1"]
    end
  end

  describe "update_position/3" do
    test "updates an existing player's position" do
      {:ok, state} =
        "match-1"
        |> State.new()
        |> State.add_player("player-1")

      pos = %{"x" => 1, "y" => 0, "z" => -2}

      state = State.update_position(state, "player-1", pos)

      assert state.players["player-1"].pos == pos
    end
  end

  describe "ready_to_start?/1" do
    test "requires two players and a waiting or ended phase" do
      {:ok, state} =
        "match-1"
        |> State.new()
        |> State.add_player("player-1")

      refute State.ready_to_start?(state)

      {:ok, state} = State.add_player(state, "player-2")

      assert State.ready_to_start?(state)
      assert State.ready_to_start?(%{state | phase: :ended})
      refute State.ready_to_start?(%{state | phase: :active})
    end
  end
end
