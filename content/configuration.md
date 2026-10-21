+++
title = "Configuration"
description = "Every option in Vela.toml and server.toml: deploy strategies, hooks, environment, secrets, Postgres and NATS, remote builds, TLS and backups."
[extra]
eyebrow = "Reference"
toc = true
+++

Vela reads two files. `Vela.toml` lives in your project and describes one app. `server.toml` lives on the server and describes the machine.

## Vela.toml

Read by `vela deploy` and the other client commands, from your project root.

```toml
[app]
name = "my-app"           # required: used in paths, logs and commands
domain = "my-app.com"     # required: the domain that routes to this app

[deploy]
server = "root@1.2.3.4"   # SSH target, user@host
type = "binary"           # "binary" or "beam" (default "binary")
binary = "my-app"         # entrypoint inside the release directory
health = "/health"        # GET this path, expect 200
drain = 5                 # seconds the old instance keeps its connections (default 5)
strategy = "blue-green"   # "blue-green" or "sequential" (default "blue-green")
pre_start = "bin/migrate" # runs before the app starts; failure aborts the deploy
post_deploy = "bin/notify"# runs after traffic swaps; failure is only logged

[env]
DATABASE_PATH = "${data_dir}/my-app.db"
RUST_LOG = "info"
```

### App types

**`binary`** runs a compiled program directly: Rust, Go, C, anything that builds to an executable.

**`beam`** runs an Elixir/Phoenix release from `mix release`, with `bin/server start` unless you set `binary`. The release carries its own BEAM runtime, so the server needs no Erlang or Elixir.

### Strategies

**`blue-green`** starts the new instance next to the old one. Once the health check passes, traffic swaps and the old instance drains. No request ever finds nothing listening. Use it when your state lives outside the process.

**`sequential`** stops the old instance before starting the new one, a gap of well under a second. Use it for SQLite, so two processes never write the same database file.

### Hooks

**`pre_start`** runs inside the new release directory after it is unpacked and before the app starts. A non-zero exit aborts the deploy and leaves the old instance running. Put migrations here.

**`post_deploy`** runs after the health check has passed and traffic has moved. A failure is logged and does not roll anything back. Use it for cache warming or notifications.

Both hooks see the same environment as the app: secrets, `[env]`, `PORT` and `VELA_DATA_DIR`.

### Environment

Values in `[env]` can use two substitutions:

| Variable | Expands to |
|---|---|
| `${data_dir}` | `/var/vela/apps/<name>/data`, the directory that survives deploys |
| `${secret:KEY}` | The secret `KEY`, set with `vela secret set` |

The server stores the resolved `[env]` with the app, so when the daemon restarts, every app comes back with the same environment.

### Resources

`[resources]` accepts `memory` (for example `"512M"`) and `cpu_weight`. They are not enforced yet; limits arrive with process isolation.

## Secrets

Secrets stay on the server, never in your repository. Each app's secrets live in a file readable only by Vela (mode 0600).

```sh
vela secret set my-app SECRET_KEY_BASE=...   # set or replace
vela secret list my-app                      # keys only, never values
vela secret remove my-app SECRET_KEY_BASE
```

They reach the app as environment variables. Refer to them in `[env]` as `${secret:KEY}` when the app expects a different name.

## Services

Declare what your app depends on. Vela provisions it on the first deploy and injects the connection details.

### Postgres

```toml
[services.postgres]
version = "17"               # default "17"
databases = ["myapp_prod"]
```

Vela installs PostgreSQL with apt if it is missing, creates a user and database with a generated password, and sets `DATABASE_URL` to `postgres://<db>:<password>@localhost/<db>`. The credentials are kept in `/var/vela/services/postgres/state.toml` and reused on every deploy.

### NATS

```toml
[services.nats]
version = "2.10"     # default "2.10"
jetstream = true     # default false
```

Vela downloads the NATS server from its GitHub releases, writes a config, supervises it, and sets `NATS_URL` to `nats://localhost:4222`. NATS listens on localhost only: 4222 for clients, 8222 for monitoring.

## Remote builds

Build on the server instead of your laptop, for Elixir releases or whenever cross-compiling is more trouble than it is worth.

```toml
[build]
remote = true
command = "mix release"

[build.env]
MIX_ENV = "prod"
```

`vela deploy` then needs no artifact. It uploads your committed source with `git archive HEAD`, runs the command on the server, and activates the result like any other deploy. Uncommitted changes are not included.

## server.toml

Lives at `/etc/vela/server.toml` and is read by `vela serve`. The commands your laptop runs over SSH read the same path, so keep it there.

```toml
data_dir = "/var/vela"        # apps, releases and state (default /var/vela)

[proxy]
http_port = 80                # default 80
https_port = 443              # default 443

[tls]
acme_email = "ops@example.com"  # register with Let's Encrypt
staging = false                 # use Let's Encrypt staging while testing
# cert = "/etc/vela/tls/origin.pem"          # a static certificate instead of ACME
# key = "/etc/vela/tls/origin-key.pem"
# client_ca = "/etc/vela/tls/client-ca.pem"  # require client certificates (mTLS)
```

Without a config file, Vela uses `/var/vela`, listens on 80 and 443, and serves no TLS until `acme_email` is set.

### TLS

With `acme_email`, Vela gets certificates from Let's Encrypt over HTTP-01, picks them by SNI, checks them daily and renews 30 days before they expire. Plain HTTP redirects to HTTPS, except for the ACME challenge itself.

With `cert` and `key`, Vela serves that certificate instead, for example a Cloudflare Origin certificate. Add `client_ca` and the HTTPS listener refuses any connection without a client certificate signed by that CA; with Cloudflare's Authenticated Origin Pulls, only Cloudflare can reach your server. The [Cloudflare guide](https://github.com/raskell-io/vela/blob/main/docs/cloudflare.md) walks through it.

### Backups

```toml
[backup]
schedule = "daily"                 # "hourly", "daily" or an interval like "12h"
retain = 7                         # how many backups to keep
destination = "/var/backups/vela"  # a local path or "s3://bucket/prefix"

[backup.include]
app_data = true    # app data directories; SQLite is checkpointed first
secrets = true     # each app's secrets and app.toml
postgres = true    # pg_dump of every provisioned database, gzipped
```

S3 destinations need the `aws` CLI installed and configured on the server. Run `vela backup` from your laptop to take one now.

## Commands

| Command | What it does |
|---|---|
| `vela serve` | Run the server daemon (Linux) |
| `vela setup` | Write and install the systemd unit |
| `vela init` | Create a `Vela.toml` |
| `vela deploy [<artifact>]` | Deploy; no artifact needed with remote builds |
| `vela status [--json]` | Apps with live health, PID and uptime |
| `vela logs <app> [-f]` | Show or follow an app's logs |
| `vela rollback [<app>]` | Go back to the previous release |
| `vela secret set\|list\|remove` | Manage an app's secrets |
| `vela backup` | Run a backup now |
| `vela apps` | List apps, on the server |

`vela status --json` asks the daemon for live process details and probes each health path with a 3-second timeout; `health` is `healthy`, `unhealthy`, or `unknown` when no health path is set.
