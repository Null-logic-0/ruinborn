defmodule Ruinborn.Mailer do
  @moduledoc """
  Mailer used by the Ruinborn application.

  The project does not currently send match emails, but Phoenix configures this
  Swoosh mailer for future application notifications and local mailbox preview.
  """

  use Swoosh.Mailer, otp_app: :ruinborn
end
