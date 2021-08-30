#!/bin/bash
source /vagrant/lib.sh

# install the version that better honours peerAddress.
# see https://github.com/k0sproject/k0sctl
# NB because we need https://github.com/k0sproject/k0sctl/pull/169 (https://github.com/k0sproject/k0sctl/issues/168)
# NB because we need https://github.com/k0sproject/k0sctl/pull/181 (https://github.com/k0sproject/k0sctl/issues/179)
#go install github.com/k0sproject/k0sctl@00637405fbf20c98bc8cf66adb283e1fefb39477 # OK.
#go install github.com/k0sproject/k0sctl@658cd398c053be6e227cabfc30dbcc78c13ae6a7 # broken. see https://github.com/k0sproject/k0sctl/issues/196
go install github.com/k0sproject/k0sctl@590faf64f3fa81b5c6e37d37b9ee1c5a31c0066c # OK. v0.10.0-beta.3

# move the release version out of the way.
if [ -f /usr/local/bin/k0sctl ] && [ ! -L /usr/local/bin/k0sctl ]; then
    mv /usr/local/bin/k0sctl{,.orig}
fi

# symlink to the built version.
ln -fs $HOME/go/bin/k0sctl /usr/local/bin
