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
