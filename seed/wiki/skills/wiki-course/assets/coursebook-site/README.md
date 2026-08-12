# MoonBook repository coursebook site

Copy this directory into a generated coursebook root. Rename
`coursebook.example.json` to `coursebook.json`, replace its sample content, and
write a matching `coursebook-evidence.json`.

Static preview:

```sh
python3 -m http.server 4390 --bind 127.0.0.1 --directory COURSEBOOK_ROOT
```

Preview with the optional MoonClaw pet:

```sh
PET_KNOWLEDGE_ROOT="$(mktemp -d "$PWD/COURSEBOOK_ROOT/.pet-knowledge.XXXXXX")"
cp COURSEBOOK_ROOT/coursebook.json COURSEBOOK_ROOT/coursebook-evidence.json \
  "$PET_KNOWLEDGE_ROOT/"
COURSEBOOK_SITE_ROOT=COURSEBOOK_ROOT \
COURSEBOOK_KNOWLEDGE_ROOT="$PET_KNOWLEDGE_ROOT" \
COURSEBOOK_ENABLE_PET=1 \
MOONCLAW_GATEWAY_URL=http://127.0.0.1:18123 \
MOONCLAW_MODEL=default \
node COURSEBOOK_ROOT/server.mjs
```

The pet server binds `127.0.0.1:4390` by default. Production must set
`COURSEBOOK_ALLOWED_HOSTS`, place the server behind authenticated HTTPS, and
keep the MoonClaw Gateway inaccessible to browsers. The pet is disabled unless
`COURSEBOOK_ENABLE_PET=1`; when enabled, the dedicated knowledge directory must
contain exactly the two copied public JSON files. For each question the adapter
selects no more than six relevant public pages under a 48,000-byte serialized
context budget, sends only their required source and claim evidence, and
accepts citations only to pages in that bounded context.
