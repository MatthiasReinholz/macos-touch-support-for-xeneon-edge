APP_NAME := xeneon-touch-support
BUILD_DIR := build
SRC := src/main.m
OUT := $(BUILD_DIR)/$(APP_NAME)
APP_BUNDLE_NAME := XeneonTouchSupport.app
APP_BUNDLE := $(BUILD_DIR)/$(APP_BUNDLE_NAME)
APP_CONTENTS := $(APP_BUNDLE)/Contents
APP_MACOS := $(APP_CONTENTS)/MacOS
APP_RESOURCES := $(APP_CONTENTS)/Resources
APP_EXECUTABLE := $(APP_MACOS)/XeneonTouchSupport
INFO_PLIST_SRC := packaging/Info.plist
INFO_PLIST_DST := $(APP_CONTENTS)/Info.plist
ZIP_OUT := $(BUILD_DIR)/XeneonTouchSupport-macOS.zip

CFLAGS := -fobjc-arc -Wall -Wextra -Wpedantic
FRAMEWORKS := -framework AppKit -framework ApplicationServices -framework IOKit

.PHONY: build app zip run clean

build: $(OUT)

$(OUT): $(SRC)
	mkdir -p $(BUILD_DIR)
	clang $(CFLAGS) $(FRAMEWORKS) $(SRC) -o $(OUT)

app: $(APP_EXECUTABLE) $(INFO_PLIST_DST)

$(APP_EXECUTABLE): $(OUT)
	mkdir -p "$(APP_MACOS)" "$(APP_RESOURCES)"
	cp "$(OUT)" "$(APP_EXECUTABLE)"

$(INFO_PLIST_DST): $(INFO_PLIST_SRC)
	mkdir -p "$(APP_CONTENTS)"
	cp "$(INFO_PLIST_SRC)" "$(INFO_PLIST_DST)"

zip: app
	rm -f "$(ZIP_OUT)"
	cd "$(BUILD_DIR)" && ditto -c -k --sequesterRsrc --keepParent "$(APP_BUNDLE_NAME)" "$(notdir $(ZIP_OUT))"

run: $(OUT)
	./$(OUT)

clean:
	rm -rf $(BUILD_DIR)
