# apple-contacts

A command-line interface for Apple Contacts that uses JavaScript for Automation (JXA) for fast, read-only access to your contacts.

## Features

- **Fast search**: Search contacts by name, email, phone, organization, and more
- **Multiple search criteria**: Combine filters with AND logic
- **Birthday search**: Find contacts by birthday date or month
- **Full-text search**: Search across all fields at once
- **Duplicate handling**: Automatic ID display when contacts share names
- **vCard export**: Export contacts in standard vCard format
- **Group support**: List groups and filter contacts by group
- **JSON output**: Machine-readable output for scripting

## Installation

### Homebrew

```bash
brew install fishfisher/tap/apple-contacts
```

### From Source

```bash
go install github.com/fishfisher/apple-contacts@latest
```

### Binary Download

Download the latest release from the [releases page](https://github.com/fishfisher/apple-contacts/releases).

## Usage

### Search contacts by name

```bash
apple-contacts search fisher
```

### Search by email domain

```bash
apple-contacts search --email "@company.com"
```

### Search by organization

```bash
apple-contacts search --org "Acme Corp"
```

### Search by phone number

```bash
apple-contacts search --phone "+47"
```

### Find birthdays

```bash
# Specific date (MM-DD format)
apple-contacts search --birthday "01-25"

# All January birthdays
apple-contacts search --birthday-month 1
```

### Search in notes

```bash
apple-contacts search --note "VIP"
```

### Search in addresses

```bash
apple-contacts search --address "Oslo"
```

### Search all fields

```bash
apple-contacts search --any "fisher"
```

### Combine multiple criteria

```bash
# Name AND organization
apple-contacts search fisher --org "Acme"

# Email domain AND address
apple-contacts search --email "@company.com" --address "New York"
```

### Show full contact details

```bash
apple-contacts show "Erik Fisher"

# By ID (for duplicates)
apple-contacts show --id "ABC123-DEF456:ABPerson"
```

### List all contacts

```bash
apple-contacts list

# Limit results
apple-contacts list --limit 20

# Filter by group
apple-contacts list --group "Family"
```

### List groups

```bash
apple-contacts groups
```

### Export as vCard

```bash
# To stdout
apple-contacts export "Erik Fisher"

# To file
apple-contacts export "Erik Fisher" --output erik.vcf

# By ID
apple-contacts export --id "ABC123-DEF456:ABPerson"
```

### JSON output

All commands support `--json` for machine-readable output:

```bash
apple-contacts search fisher --json
apple-contacts show "Erik Fisher" --json
apple-contacts list --json
apple-contacts groups --json
```

## Commands

| Command | Description |
|---------|-------------|
| `search [term]` | Search contacts by name or other criteria |
| `show [name]` | Show full contact details |
| `list` | List all contacts |
| `groups` | List contact groups |
| `export [name]` | Export contact as vCard |

### Search Flags

| Flag | Description |
|------|-------------|
| `--email` | Search by email address (contains) |
| `--phone` | Search by phone number (contains) |
| `--org` | Search by organization (contains) |
| `--note` | Search in notes (contains) |
| `--address` | Search in addresses (contains) |
| `--birthday` | Search by birthday (MM-DD format) |
| `--birthday-month` | Search by birthday month (1-12) |
| `--any` | Search across all fields |
| `--show-id` | Force showing contact IDs |
| `--limit` | Limit number of results |
| `--json` | Output as JSON |

### Handling Duplicate Names

When search results contain contacts with the same name, IDs are automatically displayed:

```
$ apple-contacts search "John Smith"
NAME        PHONE           EMAIL              ID
John Smith  +1 555-1234     john@work.com      ABC123-DEF456:AB...
John Smith  +1 555-5678     johnsmith@home.com DEF789-GHI012:AB...

Found 2 contact(s)
(IDs shown due to duplicate names - use 'show --id <ID>' for specific contact)
```

Use the ID with `show --id` or `export --id` to target a specific contact.

## How It Works

`apple-contacts` uses JavaScript for Automation (JXA) via `osascript` to query Apple Contacts. This provides:

- **Read-only access**: Safe, non-destructive operations
- **No database access**: Works through the official Contacts API
- **Full sync support**: Sees all contacts including iCloud-synced ones
- **Rich data access**: Phones, emails, addresses, birthdays, notes, and more

## Limitations

- **macOS only**: Uses Apple's JXA which is macOS-specific
- **Read-only**: Cannot create, edit, or delete contacts (use Contacts.app for that)
- **Performance**: Large contact lists may take a moment to search (queries run through AppleScript)

## Development

```bash
# Clone the repository
git clone https://github.com/fishfisher/apple-contacts.git
cd apple-contacts

# Build
make build

# Run
./apple-contacts --help
```

## License

MIT

## Related

- [apple-notes](https://github.com/fishfisher/apple-notes) - CLI for Apple Notes
