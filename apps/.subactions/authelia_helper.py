#!/usr/bin/env python3
"""
Authelia Configuration Helper for DockServer
Safely adds or removes bypass rules in Authelia configuration.yml without line-number guesswork.
"""

import sys
import re
import os

def add_domain(conf_path, domain):
    if not os.path.exists(conf_path):
        print(f"Error: {conf_path} does not exist", file=sys.stderr)
        return False

    with open(conf_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Check if domain is already in the file
    domain_escaped = re.escape(domain)
    if re.search(r'-\s*(?:domain:\s*)?["\']?' + domain_escaped + r'["\']?', content):
        print(f"Domain {domain} is already configured in Authelia rules.")
        return True

    # Find the rules section under access_control
    # We look for 'access_control:' followed by 'rules:'
    lines = content.splitlines(keepends=True)
    insert_idx = -1
    in_access_control = False

    for idx, line in enumerate(lines):
        if re.match(r'^\s*access_control\s*:', line):
            in_access_control = True
        elif in_access_control and re.match(r'^\s*rules\s*:', line):
            insert_idx = idx + 1
            break

    if insert_idx == -1:
        print(f"Could not locate access_control -> rules in {conf_path}", file=sys.stderr)
        return False

    rule_lines = [
        f"    - domain: {domain}\n",
        "      policy: bypass\n"
    ]

    new_lines = lines[:insert_idx] + rule_lines + lines[insert_idx:]

    with open(conf_path, 'w', encoding='utf-8') as f:
        f.writelines(new_lines)

    print(f"Added bypass rule for {domain} in {conf_path}")
    return True

def remove_domain(conf_path, domain):
    if not os.path.exists(conf_path):
        return True

    with open(conf_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    domain_escaped = re.escape(domain)
    new_lines = []
    skip_next = False

    for line in lines:
        if skip_next:
            # If previous line was the standalone domain rule, skip the policy line associated with it
            if re.match(r'^\s*policy\s*:', line):
                skip_next = False
                continue
            skip_next = False

        # Match single-rule format: "- domain: plex.example.com"
        if re.search(r'-\s*domain:\s*["\']?' + domain_escaped + r'["\']?', line):
            skip_next = True
            continue

        # Match list-item format: "  - 'plex.example.com'" or "  - plex.example.com"
        if re.match(r'^\s*-\s*["\']?' + domain_escaped + r'["\']?\s*(?:#.*)?$', line):
            continue

        new_lines.append(line)

    with open(conf_path, 'w', encoding='utf-8') as f:
        f.writelines(new_lines)

    print(f"Removed rule for {domain} from {conf_path}")
    return True

if __name__ == "__main__":
    if len(sys.argv) < 4:
        print("Usage: authelia_helper.py <add|remove> <config_path> <domain>")
        sys.exit(1)

    action = sys.argv[1].lower()
    config_file = sys.argv[2]
    target_domain = sys.argv[3]

    if action == "add":
        success = add_domain(config_file, target_domain)
        sys.exit(0 if success else 1)
    elif action == "remove":
        success = remove_domain(config_file, target_domain)
        sys.exit(0 if success else 1)
    else:
        print(f"Unknown action: {action}")
        sys.exit(1)
