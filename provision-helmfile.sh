#!/bin/bash
set -euo pipefail

#
# deploy helmfile.

helmfile_version="${1:-0.148.1}"; shift || true

# install helmfile.
# see https://github.com/helmfile/helmfile#installation
echo "installing helmfile $helmfile_version..."
case `uname -m` in
    x86_64)
        wget -qOhelmfile.tgz "https://github.com/helmfile/helmfile/releases/download/v$helmfile_version/helmfile_${helmfile_version}_linux_amd64.tar.gz"
        ;;
    armv7l)
        wget -qOhelmfile.tgz "https://github.com/helmfile/helmfile/releases/download/v$helmfile_version/helmfile_${helmfile_version}_linux_arm64.tar.gz"
        ;;
esac
tar xf helmfile.tgz helmfile
install helmfile /usr/local/bin
rm helmfile.tgz

# kick the tires.
printf "#\n# helmfile version\n#\n"
helmfile version
