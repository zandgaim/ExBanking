# config/config.exs
import Config

config :logger, :console,
  format: "$message\n",
  backends: [:console],
  level: :info
