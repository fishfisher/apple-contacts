// Auto-generated from apple-contacts-skill/SKILL.md by `make skill`.
// Do not edit directly.

enum EmbeddedSkill {
    static let skillMD = #"""
---
name: apple-contacts
description: Search and view Apple Contacts from the command line using apple-contacts CLI. Use when asked to search, list, show, or export contacts, find birthdays, browse contact groups, or look up people by name, email, phone, organization, or address. Read-only access using Apple's native Contacts Framework for fast, reliable lookups.
metadata: {"clawdbot":{"emoji":"📇","requires":{"bins":["apple-contacts"]}}}
---

# Apple Contacts

Read-only access to Apple Contacts through the native Contacts framework.

## Install

```bash
fishtools install apple-contacts   # upgrade: fishtools upgrade apple-contacts
apple-contacts permissions   # asks for Contacts access once
```

Requires macOS 14+.

## Workflow for agents

1. `apple-contacts search <term> --json` — rows include `id`, `name`, `organization`, `phones`, `emails`, `birthday`, so you rarely need `show`.
2. When you need everything (addresses, relations, URLs, dates): `apple-contacts show --id <id> --json`.
3. `show "<name>"` works when the name identifies one person. If several match, it fails (exit 1) and lists each candidate's `--id` — pick one, don't guess.

## Search

```bash
apple-contacts search "fisher"                    # name or nickname
apple-contacts search --email "@company.com"
apple-contacts search --phone "900 00 000"        # also +4790000000, 004790000000
apple-contacts search --org "Acme"
apple-contacts search --address "Oslo"
apple-contacts search --any "keyword"             # name, org, email, address, phone
apple-contacts search --birthday 01-25            # also 1-25, 25.01, YYYY-MM-DD
apple-contacts search --birthday-month 12
apple-contacts search "erik" --org "Agens" --limit 5 --json
```

- Text matches anywhere and ignores case and accents; `o`/`ae`/`a`/`aa` also match `ø`/`æ`/`å`.
- Phone numbers match regardless of spaces and `+47`/`0047`.
- All given criteria must match (AND), `--any` included.
- Results come in Contacts' sort order. An invalid `--birthday` or `--limit` is an error, not "everything".

## Other commands

```bash
apple-contacts list [--limit N] [--group "name" | --group-id <id>] [--json]   # group name is case-insensitive
apple-contacts show "<name>" | --id <id> [--json]   # all fields; addresses also split into street/postalCode/city/country
apple-contacts groups [--json]
apple-contacts export "<name>" | --id <id> [--output file.vcf]   # vCard
apple-contacts permissions [--reset]
apple-contacts install-skill [--path <dir>] [--force]
```

Birthdays are `YYYY-MM-DD`, or `--MM-DD` when the year is unknown.

## Exit codes

- 0 ok · 1 not found / ambiguous name / other error · 64 invalid arguments · 77 no Contacts access

## Permissions from agents

- On 77, run `apple-contacts permissions`. It shows the macOS prompt when access was never asked for. If access was denied, the user must enable it in System Settings > Privacy & Security > Contacts.
- Agent sandboxes (Codex/ChatGPT) may not get the prompt at all. If an `apple-contacts-codex` wrapper is on this Mac, use it with the same arguments. It launches a signed app copy that holds its own Contacts permission. Never reset permissions for other apps or edit TCC databases.

## Limitations

- Read-only: no creating, editing or deleting contacts.
- Contact notes need an Apple entitlement and aren't available.

"""#
}
