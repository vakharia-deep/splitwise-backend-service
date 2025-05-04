import Config

# Do not print debug messages in production
config :logger, level: :info

config :splitwise, SplitwiseWeb.Endpoint,
  load_from_system_env: true,
  check_origin: false,
  server: true,
  root: ".",
  url: [host: "/", path: "/", port: "4000"]

# Runtime production configuration, including reading
# of environment variables, is done on config/runtime.exs.
