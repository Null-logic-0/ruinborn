defmodule RuinbornWeb.ChannelCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      use ExUnit.Case

      import Phoenix.ChannelTest
      @endpoint RuinbornWeb.Endpoint
    end
  end
end
