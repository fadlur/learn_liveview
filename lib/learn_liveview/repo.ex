defmodule LearnLiveview.Repo do
  use Ecto.Repo,
    otp_app: :learn_liveview,
    adapter: Ecto.Adapters.Postgres
end
