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
# deSEC API Token
token="your_desec_token_here"

# Domain to be updated
kodihost="your.domain.here"
```

If no configuration file exists, the script will create a template that you can customize.

## How It Works

1. Retrieves your current public IPv4 and IPv6 addresses
2. Checks the current DNS records for your domain
3. Updates the DNS records only if your IP addresses have changed
4. Provides execution time statistics

## Requirements

- Bash shell
- Either `drill` or `host` command for DNS lookups
- `curl` for API requests and IP detection

## License

Copyright © 2024 Michael N.

Quellen
[1] GitHub Flavored Markdown Spec https://github.github.com/gfm/
[2] Quickstart for writing on GitHub https://docs.github.com/en/get-started/writing-on-github/getting-started-with-writing-and-formatting-on-github/quickstart-for-writing-on-github
[3] Creating and highlighting code blocks - GitHub Docs https://docs.github.com/en/get-started/writing-on-github/working-with-advanced-formatting/creating-and-highlighting-code-blocks
[4] Basic writing and formatting syntax - GitHub Docs https://docs.github.com/articles/basic-writing-and-formatting-syntax
[5] Github Markdown Cheat Sheet - JavaScript in Plain English https://javascript.plainenglish.io/github-markdown-cheat-sheet-everything-you-need-to-know-to-write-readme-md-ce40369da21f
[6] markdown-it demo https://markdown-it.github.io
[7] About writing and formatting on GitHub https://docs.github.com/articles/about-writing-and-formatting-on-github
[8] Markdown Cheatsheet · adam-p/markdown-here Wiki - GitHub https://github.com/adam-p/markdown-here/wiki/markdown-cheatsheet
