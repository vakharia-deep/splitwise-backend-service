# Use the official Elixir image
FROM elixir:1.15-alpine as build

# Install Hex + Rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Install Node.js for asset compilation
RUN apk add --no-cache nodejs npm git build-base

# Set build env
ENV MIX_ENV=prod

# Set workdir
WORKDIR /app

# Copy mix files and install deps
COPY mix.exs mix.lock ./
COPY config ./config
RUN mix deps.get --only prod
RUN mix deps.compile

# Copy the rest of the app
COPY . .

# Compile assets if present
RUN if [ -f assets/package.json ]; then \
      cd assets && npm install && npm run deploy; \
      cd .. && mix phx.digest; \
    fi

# Compile the app
RUN mix compile

# Build release
RUN mix release

# Start a new, minimal image for runtime
FROM alpine:3.18 AS app
RUN apk add --no-cache libstdc++ openssl ncurses-libs bash
WORKDIR /opt/app

# Copy release from build
COPY --from=build /app/_build/prod/rel/splitwise .
COPY deploy/run-server.sh /opt/app/deploy/

# Make the script executable
RUN chmod +x /opt/app/deploy/run-server.sh

ENV HOME=/opt/app
ENV MIX_ENV=prod
ENV PORT=4000

ENTRYPOINT ["/opt/app/deploy/run-server.sh"] 