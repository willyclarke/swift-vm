PROJECT  := SwiftVM.xcodeproj
SCHEME   := SwiftVM
CONFIG   := Release
BUILD_DIR := build
DERIVED  := $(BUILD_DIR)/DerivedData
APP      := $(DERIVED)/Build/Products/$(CONFIG)/SwiftVM.app
STAGING  := $(BUILD_DIR)/.dmg-staging
ENTITLEMENTS_DEFAULT := SwiftVM/SwiftVM.entitlements
ENTITLEMENTS_BRIDGED := SwiftVM/SwiftVM-Bridged.entitlements

VERSION  = $(shell test -f "$(APP)/Contents/Info.plist" && \
             /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" \
             "$(APP)/Contents/Info.plist" 2>/dev/null || echo "dev")
DMG      = $(BUILD_DIR)/SwiftVM-$(VERSION).dmg

.PHONY: build build-bridged install dmg notarize clean help

help:
	@echo "Targets:"
	@echo "  build         — compile Release .app (NAT networking, default entitlements)"
	@echo "  build-bridged — compile Release .app with com.apple.vm.networking entitlement"
	@echo "                  (requires Apple approval — see CLAUDE.md)"
	@echo "  install       — build and copy SwiftVM.app to /Applications"
	@echo "  dmg           — build and package into a distributable DMG"
	@echo "  notarize      — submit DMG to Apple notarization and staple ticket"
	@echo "  clean         — remove all build artefacts"

## Compile a Release build (NAT networking, default entitlements).
build: _update-build-info
	xcodebuild \
	  -project "$(PROJECT)" \
	  -scheme "$(SCHEME)" \
	  -configuration "$(CONFIG)" \
	  -derivedDataPath "$(DERIVED)" \
	  CODE_SIGN_ENTITLEMENTS="$(ENTITLEMENTS_DEFAULT)" \
	  build

## Compile a Release build with bridged networking entitlement.
## Requires com.apple.vm.networking approval from Apple — see CLAUDE.md.
build-bridged: _update-build-info
	xcodebuild \
	  -project "$(PROJECT)" \
	  -scheme "$(SCHEME)" \
	  -configuration "$(CONFIG)" \
	  -derivedDataPath "$(DERIVED)" \
	  CODE_SIGN_ENTITLEMENTS="$(ENTITLEMENTS_BRIDGED)" \
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

_update-build-info:
	@bash scripts/update-build-info.sh

## Remove all build artefacts.
clean:
	rm -rf "$(BUILD_DIR)"
