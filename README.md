# Ruinborn

Ruinborn is a Phoenix-powered real-time multiplayer match server. It uses Phoenix Channels to let players join match rooms, move through a shared arena, attack opponents, and receive live match events.

## Features

- Real-time match rooms over Phoenix Channels
- Two-player room capacity with duplicate rejoin handling
- Match lifecycle state for waiting, countdown, active, and ended phases
- Player health, alive/dead state, and 3D position tracking
- Combat rules for weapon range, damage, misses, and deaths
- Channel broadcasts for joins, movement, health updates, deaths, countdowns, and match endings
- Focused unit and channel test coverage

## Requirements

- Elixir 1.15 or later
- Erlang/OTP compatible with your Elixir version
- Phoenix dependencies installed through Mix

## Setup

Install dependencies:

```sh
mix setup
```

Run the test suite:

```sh
mix test
```

Run the project checks used before committing:

```sh
mix precommit
```

Generate project documentation:

```sh
mix docs
```

## Development

Start the Phoenix server:

```sh
mix phx.server
```

Or start it inside IEx:

```sh
iex -S mix phx.server
```

Then visit [localhost:4000/test.html](http://localhost:4000/test.html).

## Project Structure

- `lib/ruinborn/match/state.ex` contains pure match state transitions.
- `lib/ruinborn/match/combat.ex` contains combat calculations and attack resolution.
- `lib/ruinborn/match_server.ex` wraps match state in a GenServer process.
- `lib/ruinborn_web/channels/match_channel.ex` exposes the real-time channel API.
- `test/` contains unit and channel tests.

## Channel Events

Clients join a match by connecting to:

```text
match:<match_id>
```

Supported inbound events:

- `move` with a `pos` payload updates the player's position.
- `attack` with `weapon` and `pos` resolves an attack from the player.
- `ping` replies with `{pong: true}`.

Notable outbound events include:

- `player_joined`
- `player_left`
- `player_moved`
- `hp_update`
- `player_died`
- `countdown`
- `match_start`
- `match_ended`

## License

Ruinborn is released under the MIT License. See [LICENSE](LICENSE) for details.
