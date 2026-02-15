build:
	xcodebuild -configuration Release -alltargets SYMROOT="$(CURDIR)/build"

xcode:
	open *.xcodeproj

swift-format:
	find * -name '*.swift' -print0 | xargs -0 swift-format -i

swiftlint:
	swiftlint
