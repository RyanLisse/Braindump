.PHONY: build test clean run mcp sync release install

# Default target
all: build

# Build the project (debug)
build:
	swift build

# Build for release
release:
	swift build -c release

# Run tests
test:
	swift test

# Clean build artifacts
clean:
	swift package clean

# Run the MCP server
mcp:
	swift run braindump mcp

# Run the sync command
sync:
	swift run braindump sync

# Run the CLI (usage: make run args="notes list")
run:
	swift run braindump $(args)

# Install to /usr/local/bin (requires sudo usually, but we won't force it here)
install: release
	install .build/release/braindump /usr/local/bin/braindump
