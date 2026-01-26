# apple-contacts

A fast command-line interface for Apple Contacts that uses Apple's native Contacts Framework for direct, read-only access to your contacts.

## Features

- **Fast search**: Native Contacts Framework provides fast lookups using built-in predicates
- **Multiple search criteria**: Combine filters with AND logic
- **Birthday search**: Find contacts by birthday date or month
- **Full-text search**: Search across all fields at once
- **Contact IDs**: Every result includes the contact ID for unambiguous lookups
- **vCard export**: Export contacts in standard vCard format
- **Group support**: List groups and filter contacts by group
- **JSON output**: Machine-readable output for scripting

## Installation

### From Source (Swift)

```bash
git clone https://github.com/fishfisher/apple-contacts.git
cd apple-contacts
swift build -c release
cp .build/release/apple-contacts /usr/local/bin/
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
| `--address` | Search in addresses (contains) |
| `--birthday` | Search by birthday (MM-DD format) |
| `--birthday-month` | Search by birthday month (1-12) |
| `--any` | Search across all fields |
| `--limit` | Limit number of results |
| `--json` | Output as JSON |

## How It Works

`apple-contacts` uses Apple's native Contacts Framework (`CNContactStore`) for fast, direct access to contacts:

- **Native API**: Uses the same framework as the Contacts app
- **Fast predicates**: Name and email searches use built-in database predicates
- **Read-only access**: Safe, non-destructive operations
- **Full sync support**: Sees all contacts including iCloud-synced ones
- **Rich data access**: Phones, emails, addresses, birthdays, social profiles, and more

## Permissions

On first run, macOS will prompt you to grant Contacts access. You can also grant access manually in:

**System Settings > Privacy & Security > Contacts**

## Limitations

- **macOS only**: Uses Apple's Contacts Framework which is macOS-specific
- **Read-only**: Cannot create, edit, or delete contacts (use Contacts.app for that)
- **Notes field**: Not accessible from CLI apps without special Apple entitlements

## Development

```bash
# Clone the repository
git clone https://github.com/fishfisher/apple-contacts.git
cd apple-contacts

# Build
swift build

# Run
.build/debug/apple-contacts --help

# Release build
swift build -c release
```

## Requirements

- macOS 14.0 or later
- Swift 6.0 or later

## License

MIT

## Related

- [apple-notes](https://github.com/fishfisher/apple-notes) - CLI for Apple Notes
