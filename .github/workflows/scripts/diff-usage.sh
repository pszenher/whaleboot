#!/usr/bin/env bash

set -o errexit -o pipefail -o noclobber -o nounset

self_path="$(
    cd -- "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1
    pwd -P
)"
repo_root="$(
    cd "${self_path}"
    git rev-parse --show-toplevel
)"

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
