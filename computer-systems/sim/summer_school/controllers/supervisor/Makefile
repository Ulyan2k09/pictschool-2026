# Portable Webots controller Makefile
# Windows / Linux / macOS

CONTROLLER = supervisor

C_SOURCES = supervisor.c movement_layer.c

ifeq ($(OS),Windows_NT)
  WEBOTS_HOME ?= C:/Program Files/Webots
  HOST_PLATFORM := windows
  LIBRARIES += -lws2_32
else
  ifeq ($(shell uname),Darwin)
    WEBOTS_HOME ?= /Applications/Webots.app
    HOST_PLATFORM := darwin-$(shell uname -m)
  else
    WEBOTS_HOME ?= /usr/local/webots
    HOST_PLATFORM := linux-$(shell uname -m)
  endif
endif

null :=
space := $(null) $(null)
WEBOTS_HOME_PATH := $(subst $(space),\ ,$(strip $(subst \,/,$(WEBOTS_HOME))))

.PHONY: prepare-platform
all release debug profile: prepare-platform

prepare-platform:
	@mkdir -p build
	@if [ ! -f build/.webots-platform ] || [ "$$(cat build/.webots-platform)" != "$(HOST_PLATFORM)" ]; then \
		rm -rf build; \
		mkdir -p build; \
		echo "$(HOST_PLATFORM)" > build/.webots-platform; \
	fi

ifneq ($(wildcard $(CURDIR)/resources/Makefile.include),)
  include $(CURDIR)/resources/Makefile.include
else
  include $(WEBOTS_HOME_PATH)/resources/Makefile.include
endif
