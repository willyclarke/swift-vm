PROJECT  := SwiftVM.xcodeproj
SCHEME   := SwiftVM
CONFIG   := Release
BUILD_DIR := build
DERIVED  := $(BUILD_DIR)/DerivedData
APP      := $(DERIVED)/Build/Products/$(CONFIG)/SwiftVM.app
STAGING  := $(BUILD_DIR)/.dmg-staging

VERSION  = $(shell test -f "$(APP)/Contents/Info.plist" && \
             /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" \
             "$(APP)/Contents/Info.plist" 2>/dev/null || echo "dev")
DMG      = $(BUILD_DIR)/SwiftVM-$(VERSION).dmg

.PHONY: build install dmg notarize clean help

help:
	@echo "Targets:"
	@echo "  build     — compile Release .app into $(DERIVED)"
	@echo "  install   — build and copy SwiftVM.app to /Applications"
	@echo "  dmg       — build and package into a distributable DMG"
	@echo "  notarize  — submit DMG to Apple notarization and staple ticket"
	@echo "  clean     — remove all build artefacts"

## Compile a Release build.
build:
	xcodebuild \
	  -project "$(PROJECT)" \
	  -scheme "$(SCHEME)" \
	  -configuration "$(CONFIG)" \
	  -derivedDataPath "$(DERIVED)" \
	  build

## Build and install to /Applications.
install: build
	@echo "Installing to /Applications/SwiftVM.app…"
	rm -rf /Applications/SwiftVM.app
	cp -R "$(APP)" /Applications/SwiftVM.app
	@echo "Done."

## Build and create a drag-to-install DMG.
dmg: build
	@rm -rf "$(STAGING)"
	@mkdir -p "$(STAGING)"
	cp -R "$(APP)" "$(STAGING)/SwiftVM.app"
	ln -s /Applications "$(STAGING)/Applications"
	hdiutil create \
	  -volname "SwiftVM" \
	  -srcfolder "$(STAGING)" \
	  -ov \
	  -format UDZO \
	  "$(DMG)"
	@rm -rf "$(STAGING)"
	@echo "Created $(DMG)"

## Notarize and staple the DMG for Gatekeeper-clean distribution.
##
## One-time setup (replace values with your own):
##   xcrun notarytool store-credentials "swiftvm-notarytool" \
##     --apple-id "you@example.com" \
##     --team-id "XXXXXXXXXX" \
##     --password "<app-specific-password>"
##
## Also requires the Xcode project to use a Developer ID Application
## certificate (not the default Development certificate) and have
## Hardened Runtime enabled in Signing & Capabilities.
notarize: dmg
	xcrun notarytool submit "$(DMG)" \
	  --keychain-profile "swiftvm-notarytool" \
	  --wait
	xcrun stapler staple "$(DMG)"
	@echo "Notarized and stapled $(DMG)"

## Remove all build artefacts.
clean:
	rm -rf "$(BUILD_DIR)"
