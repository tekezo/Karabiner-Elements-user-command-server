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
