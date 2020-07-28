# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

config :testfunctiondb,
  ecto_repos: [Testfunctiondb.Repo]

# Configures the endpoint
config :testfunctiondb, TestfunctiondbWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "AKrT1CmubjrJpY/oRJDq2N/ZAJhJuAETetQO+dGKGpYjqu40dLHXv9QGlB4bIh8H",
  render_errors: [view: TestfunctiondbWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: Testfunctiondb.PubSub,
  live_view: [signing_salt: "paQssguB"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
