# vela.raskell.io

Website for [Vela](https://github.com/raskell-io/vela), no-downtime app deployment on bare
metal.

**Live:** https://vela.raskell.io

## Quick start

```bash
mise install          # tools
mise run serve        # http://127.0.0.1:1111
```

## Tasks

| Task | Description |
|------|-------------|
| `mise run serve` | Dev server with live reload |
| `mise run build` | Build the site into `public/` |
| `mise run check` | Build and check internal links |
| `mise run icons` | Render favicons, app icons and the social card (resvg, ImageMagick, Chrome) |
| `mise run clean` | Remove `public/` |

## Structure

```
vela.raskell.io/
├── config.toml            # Zola configuration; extra.version is the Vela release shown on the site
├── content/               # Getting started, configuration reference
├── sass/style.scss        # The icon's palette: night navy, sail white, jib teal; Archivo + JetBrains Mono
├── art/og.html            # Social card source
├── scripts/
│   ├── cf-pages-build.sh  # Cloudflare Pages build command
│   └── render-icons.sh    # static/img/logo.svg -> favicons, app icons; art/og.html -> og-image.png
├── static/                # Logo, icons, social card, _headers, robots.txt
└── templates/             # Zola templates; the home page and its deploy animation are in index.html
```

The pages follow [Vela's docs](https://github.com/raskell-io/vela/tree/main/docs). When a release
changes behaviour or options, update `content/`, the home page and `extra.version` with it.

## Deploy

Cloudflare Pages, connected to this repository. Build command `scripts/cf-pages-build.sh`,
output directory `public`. Every push to `main` deploys.
