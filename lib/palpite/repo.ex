defmodule Palpite.Repo do
  use Ecto.Repo,
    otp_app: :palpite,
    adapter: Ecto.Adapters.SQLite3
end
