# Use the official Elixir image
FROM elixir:1.15-otp-26-alpine

# Install build dependencies
RUN apk add --no-cache \
    build-base \
    nodejs \
    npm \
    git \
    inotify-tools

# Set environment variables
ENV MIX_ENV=dev
ENV PORT=4000

# Create app directory
WORKDIR /app

# Copy dependency files
COPY mix.exs mix.lock ./

# Install hex and rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Install dependencies
RUN mix deps.get

# Copy application source
COPY . .

# Install assets dependencies
RUN cd assets && npm install
RUN mix assets.deploy

# Compile application
RUN mix compile

# Expose port
EXPOSE 4000

# Start the application
CMD ["mix", "phx.server"]