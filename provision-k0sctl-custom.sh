#!/bin/bash
source /vagrant/lib.sh

# clone my repo which reverts f6074e98d22cd95684db9a480604cf881aeb3915
git clone -b revert-f6074 https://github.com/rgl/k0sctl
cd k0sctl
go build
ln -fs $PWD/k0sctl /usr/local/bin
exit 0

# install the version that better honours peerAddress.
# see https://github.com/k0sproject/k0sctl
# NB because we need https://github.com/k0sproject/k0sctl/pull/169 (https://github.com/k0sproject/k0sctl/issues/168)
# NB because we need https://github.com/k0sproject/k0sctl/pull/181 (https://github.com/k0sproject/k0sctl/issues/179)
go install github.com/k0sproject/k0sctl@00637405fbf20c98bc8cf66adb283e1fefb39477

# move the release version out of the way.
if [ -f /usr/local/bin/k0sctl ] && [ ! -L /usr/local/bin/k0sctl ]; then
    mv /usr/local/bin/k0sctl{,.orig}
fi

# symlink to the built version.
ln -fs $HOME/go/bin/k0sctl /usr/local/bin
