# deSEC-DNS-Updater-BASH

A Bash script that automatically updates DNS records at deSEC.io with your current IP addresses.

## Features

- Updates both IPv4 and IPv6 records
- Detects changes in IP addresses to avoid unnecessary updates
- Supports configuration via external file
- Command-line option for specifying custom configuration path
- Creates template configuration file if none exists

## Usage

```bash
# Run with default configuration file (./config.sh)
./desec.sh

# Run with custom configuration file
./desec.sh -c /path/to/your/config.sh
```

## Configuration

The script requires a configuration file with the following variables:

```bash
#!/bin/bash
# Konfigurationsdatei für desec.sh

# deSEC API Token
token="dein_desec_token_hier_eintragen"

# deSEC Domain
domain="deine.domain.hier.eintragen"

# deSEC host
subname="deine.host.hier.eintragen"
```

If no configuration file exists, the script will create a template that you can customize.

## How It Works

1. Retrieves your current public IPv4 and IPv6 addresses
2. Checks the current DNS records for your domain
3. Updates the DNS records only if your IP addresses have changed
4. Provides execution time statistics

## Requirements

- Bash shell
- `curl` for API requests and IP detection

## License

Copyright © 2024 Michael N.
