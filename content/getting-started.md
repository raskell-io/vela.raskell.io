+++
title = "Getting started"
description = "Install Vela on a Linux server and your laptop, and deploy your first app with zero downtime. About ten minutes."
[extra]
eyebrow = "Tutorial"
toc = true
next = { title = "Configuration", url = "/configuration/" }
+++

## What you need

- A Linux server: a dedicated machine, bare metal or any VPS, with ports 80 and 443 open
- SSH access to it with key-based authentication
- A domain whose DNS points at the server
- An app that builds to a binary (Rust, Go, anything compiled) or an Elixir/Phoenix release

## Install Vela on the server

SSH into the server and run the install script. It detects linux/amd64 or linux/arm64, downloads the latest release and puts it in `/usr/local/bin/vela`.

```sh
curl -fsSL https://raw.githubusercontent.com/raskell-io/vela/main/install.sh | bash
```

To pin a version or install somewhere else:

```sh
curl -fsSL https://raw.githubusercontent.com/raskell-io/vela/main/install.sh | bash -s -- --version v0.5.1 --to /opt/bin
```

Create the server config. Start with Let's Encrypt's staging environment so a mistake does not run into rate limits, and switch `staging` to `false` once a deploy works.

```sh
mkdir -p /etc/vela
cat > /etc/vela/server.toml <<'EOF'
data_dir = "/var/vela"

[proxy]
http_port = 80
https_port = 443

[tls]
acme_email = "you@example.com"
staging = true
EOF
```

The config must live at `/etc/vela/server.toml`: the commands your laptop runs over SSH read it from there.

Install the daemon as a systemd service and start it:

```sh
vela setup
sudo systemctl enable --now vela
```

`vela setup` writes a hardened unit file. To try things by hand instead, run `RUST_LOG=info vela serve --config /etc/vela/server.toml`. Either way the daemon has to be running before you deploy; it listens on `/var/vela/vela.sock`, and a deploy without it fails with "failed to connect to vela daemon".

## Install Vela on your laptop

The same script works on macOS and Linux, amd64 and arm64:

```sh
curl -fsSL https://raw.githubusercontent.com/raskell-io/vela/main/install.sh | bash
```

Without sudo, install into your home directory:

```sh
curl -fsSL https://raw.githubusercontent.com/raskell-io/vela/main/install.sh | bash -s -- --to ~/.local/bin
```

Or build from source with Rust 1.93 or later:

```sh
cargo install --git https://github.com/raskell-io/vela
```

## Describe your app

In your app's repository:

```sh
cd my-app
vela init --name my-app --domain my-app.example.com
```

That writes a `Vela.toml`:

```toml
[app]
name = "my-app"
domain = "my-app.example.com"

[deploy]
server = "root@your-server.example.com"
type = "binary"
binary = "my-app"
health = "/health"
```

Set `deploy.server` to your server. For an Elixir release, set `type = "beam"`.

Your app has to do four things: listen on the port in `$PORT`, return 200 on its health path within 30 seconds, shut down on `SIGTERM`, and keep anything that must survive a deploy in `$VELA_DATA_DIR`.

## Deploy

Build, then hand the artifact to Vela:

```sh
# Rust
cargo build --release
vela deploy ./target/release/my-app

# Elixir/Phoenix
MIX_ENV=prod mix release
vela deploy ./_build/prod/rel/my_app
```

```
deploying my-app to root@your-server.example.com
  uploading artifact...
  activating...
deployed my-app to root@your-server.example.com
```

Behind those four lines, Vela unpacked the release into `/var/vela/apps/my-app/releases/<timestamp>/`, started it on a random port, waited for the health check, pointed the proxy at it, and drained the previous release. If the health check had failed, the new instance would have been killed and the old one would still be serving.

## Check on it

```sh
vela status              # every app, its health, PID and uptime
vela logs my-app -f      # follow the app's output
curl https://my-app.example.com
```

Your app gets these variables, plus everything in `[env]`:

| Variable | Value |
|---|---|
| `PORT` | The port to listen on |
| `VELA_PORT` | Same as `PORT` |
| `VELA_DATA_DIR` | Persistent data directory that survives deploys |
| `VELA_APP_NAME` | Your app's name |

## Before real traffic

Go through the [production checklist](https://github.com/raskell-io/vela/blob/main/docs/production-checklist.md): firewall, DNS, moving TLS from staging to production, and what to look at when a deploy fails. Running behind Cloudflare? The [Cloudflare guide](https://github.com/raskell-io/vela/blob/main/docs/cloudflare.md) covers Origin certificates and Authenticated Origin Pulls. Deploying Phoenix? The [Elixir guide](https://github.com/raskell-io/vela/blob/main/docs/elixir-phoenix.md) covers releases, Postgres and remote builds.

## Updating Vela

Run the install script again for the latest release, or pass `--version` to pin one. Do it on the server and on your laptop.
