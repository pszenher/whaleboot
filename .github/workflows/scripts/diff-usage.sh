#!/usr/bin/env bash

repo_root="$(git rev-parse --show-toplevel)"
script_path="${repo_root}/whaleboot.sh"
readme_path="${repo_root}/README.md"

if ! diff -Bw -u --color=always \
    <(sed -rn 's/^### ?//p' "${script_path}" \
        | sed -e '1,/Usage:/ d') \
    <(sed -n '/^\[@@@\]:usage-start/,/^\[@@@\]:usage-end/{p;/^\[@@@\]:usage-end/q}' "${readme_path}" \
        | grep -v '^\[@@@\]\|^```$'); then
    echo "$(tput setaf 1)Error: usage statements in script \"${script_path}\" and" \
        "README \"${readme_path}\" differ.$(tput sgr0)"
    exit 1
fi
