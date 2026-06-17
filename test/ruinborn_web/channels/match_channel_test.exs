defmodule RuinbornWeb.MatchChannelTest do
  use RuinbornWeb.ChannelCase

  alias Ruinborn.MatchServer

  defp unique_match_id, do: "test_match_#{System.unique_integer([:positive])}"

  defp connect_player(player_id, match_id) do
    RuinbornWeb.UserSocket
    |> socket(player_id, %{player_id: player_id})
    |> subscribe_and_join(RuinbornWeb.MatchChannel, "match:#{match_id}")
  end

  describe "joining a match" do
    test "a player can join a match room" do
      match_id = unique_match_id()

      {:ok, _reply, socket} = connect_player("player_1", match_id)

      assert socket.assigns.match_id == match_id
      assert socket.assigns.player_id == "player_1"
    end

    test "joining creates a MatchServer process" do
      match_id = unique_match_id()
      connect_player("player_1", match_id)

      state = MatchServer.get_state(match_id)

      assert state.match_id == match_id
      assert state.phase == :waiting
      assert map_size(state.players) == 1
      assert Map.has_key?(state.players, "player_1")
    end

    test "two players can join the same match room" do
      match_id = unique_match_id()

      {:ok, _, socket1} = connect_player("player_1", match_id)
      {:ok, _, socket2} = connect_player("player_2", match_id)

      assert socket1.assigns.match_id == match_id
      assert socket2.assigns.match_id == match_id
    end

    test "MatchServer tracks both players after both join" do
      match_id = unique_match_id()

      connect_player("player_1", match_id)
      connect_player("player_2", match_id)

      state = MatchServer.get_state(match_id)

      assert map_size(state.players) == 2
      assert Map.has_key?(state.players, "player_1")
      assert Map.has_key?(state.players, "player_2")
      assert state.players["player_1"].hp == 100
      assert state.players["player_1"].alive == true
    end

    test "each player gets initial HP of 100" do
      match_id = unique_match_id()
      connect_player("player_1", match_id)

      state = MatchServer.get_state(match_id)

      assert state.players["player_1"] == %{
               hp: 100,
               alive: true,
               pos: %{"x" => 0, "y" => 0, "z" => 0}
             }
    end
  end

  describe "broadcasts" do
    test "when a player joins, everyone in the room is notified" do
      match_id = unique_match_id()

      connect_player("player_1", match_id)

      connect_player("player_2", match_id)

      assert_broadcast "player_joined", %{player_id: "player_2", player_count: 2}
    end

    test "the broadcast includes the current player count" do
      match_id = unique_match_id()

      # When player_1 is the only one, count = 1
      connect_player("player_1", match_id)
      assert_broadcast "player_joined", %{player_id: "player_1", player_count: 1}

      # When player_2 joins, count = 2
      connect_player("player_2", match_id)
      assert_broadcast "player_joined", %{player_id: "player_2", player_count: 2}
    end
  end

  describe "ping" do
    test "server replies with pong" do
      match_id = unique_match_id()
      {:ok, _, socket} = connect_player("player_1", match_id)

      ref = push(socket, "ping", %{})

      assert_reply ref, :ok, %{pong: true}
    end
  end
end
