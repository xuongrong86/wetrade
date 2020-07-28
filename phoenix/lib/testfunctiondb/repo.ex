defmodule Testfunctiondb.Repo do
  use Ecto.Repo,
    otp_app: :testfunctiondb,
    adapter: Ecto.Adapters.Postgres
end
