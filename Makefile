.PHONY: build test lint format check clean

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

clean:
	rm -rf .build
