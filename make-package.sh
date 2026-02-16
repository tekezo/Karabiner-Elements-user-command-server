#!/bin/bash

set -u # forbid undefined variables
set -e # forbid command failure

#
# Execute make command
#

cd $(dirname $0)

version=$(xcodebuild -configuration Release -showBuildSettings | grep MARKETING_VERSION | sed 's| ||g' | sed 's|MARKETING_VERSION=||g')

echo "make codesign"
make codesign
if [ ${PIPESTATUS[0]} -ne 0 ]; then
    exit 99
fi

#
# Create dmg
#

dmg=Karabiner-Elements-user-command-server-$version.dmg

rm -f $dmg

# create-dmg
create-dmg \
    --overwrite \
    --dmg-title KE-user-command-server \
    --identity="BD3B995B69EBA8FC153B167F063079D19CCC2834" \
    build/Release/Karabiner-Elements-user-command-server.app
mv "Karabiner-Elements-user-command-server $version.dmg" "Karabiner-Elements-user-command-server-$version.dmg"
