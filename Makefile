.PHONY: build test install uninstall reload dmg pkg clean

build:
	./Scripts/build.sh

test:
	swift test

install:
	./Scripts/install.sh

uninstall:
	pkill -TERM -f "$$HOME/Library/Input Methods/OpenBSM.app/Contents/MacOS/OpenBSMInputMethod" 2>/dev/null || true
	rm -rf "$$HOME/Library/Input Methods/OpenBSM.app"
	sudo rm -rf "/Library/Input Methods/OpenBSM.app"
	sudo pkgutil --forget dev.openbsm.inputmethod.OpenBSM.pkg 2>/dev/null || true

reload: install
	pkill -TERM -f "$$HOME/Library/Input Methods/OpenBSM.app/Contents/MacOS/OpenBSMInputMethod" 2>/dev/null || true

dmg:
	./Scripts/package-dmg.sh

pkg:
	./Scripts/package-pkg.sh

clean:
	swift package clean
