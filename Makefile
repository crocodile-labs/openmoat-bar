.PHONY: build test lint format check app clean

build:
	swift build

test:
	swift test

# What CI runs: formatting and lint must be clean.
lint:
	swiftformat --lint .
	swiftlint --strict

format:
	swiftformat .
	swiftlint --fix

check: lint build test

# MoatBar.app in the repository root.
app:
	./Scripts/package_app.sh

clean:
	rm -rf .build MoatBar.app
