VERSION = `xcodebuild -configuration Release -showBuildSettings | grep MARKETING_VERSION | sed 's| ||g' | sed 's|MARKETING_VERSION=||g'`

.PHONY: build
build:
	xcodebuild -configuration Release -alltargets SYMROOT="$(CURDIR)/build"

xcode:
	open *.xcodeproj

run:
	open build/Release/Karabiner-Elements-user-command-server.app

swift-format:
	find * -name '*.swift' -print0 | xargs -0 swift-format -i

swiftlint:
	swiftlint

codesign: build
	codesign \
		--force \
		--deep \
		--options runtime \
		--sign "BD3B995B69EBA8FC153B167F063079D19CCC2834" \
		build/Release/Karabiner-Elements-user-command-server.app

notarize:
	xcrun notarytool \
		submit Karabiner-Elements-user-command-server-$(VERSION).dmg \
		--keychain-profile "pqrs.org notarization" \
		--wait
	$(MAKE) staple
	say "notarization completed"

staple:
	xcrun stapler staple Karabiner-Elements-user-command-server-$(VERSION).dmg

check-staple:
	@xcrun stapler validate Karabiner-Elements-user-command-server-$(VERSION).dmg

notarized-dmg:
	bash make-package.sh
	$(MAKE) notarize