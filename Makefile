.PHONY: build test install clean

build:
	./Scripts/build.sh

test:
	swift test

install:
	./Scripts/install.sh

clean:
	swift package clean
