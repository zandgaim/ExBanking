# config/config.exs
import Config

config :logger, :console,
  # format: "[$level] $metadata $message \n",
  format: "$time [$level] $metadata $message \n",
  backends: [:console],
  metadata: [:request_id, :file, :line],
  level: :debug
