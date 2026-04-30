# Reels Studio bootstrap.
#
# `make` (or `make project`) regenerates the Xcode project from project.yml via
# xcodegen. Install xcodegen first: `brew install xcodegen`.

.PHONY: project clean help

project:
	@command -v xcodegen >/dev/null 2>&1 || { \
		echo "xcodegen not found. Install with: brew install xcodegen"; \
		exit 1; \
	}
	xcodegen generate

clean:
	rm -rf ReelsStudio.xcodeproj
	rm -rf .build

help:
	@echo "Targets:"
	@echo "  make project   Regenerate ReelsStudio.xcodeproj from project.yml (default)"
	@echo "  make clean     Remove generated Xcode project + SPM build dir"

.DEFAULT_GOAL := project
