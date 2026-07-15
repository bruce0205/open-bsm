.PHONY: build test install reload clean

build:
	./Scripts/build.sh

test:
	swift test

install:
	./Scripts/install.sh

reload: install
	pkill -TERM -x -f "$$HOME/Library/Input Methods/OpenBSM.app/Contents/MacOS/OpenBSMInputMethod" 2>/dev/null || true

clean:
	swift package clean
