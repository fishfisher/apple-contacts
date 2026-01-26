.PHONY: build clean test release install

build:
	swift build

release:
	swift build -c release

clean:
	rm -rf .build/
	rm -rf dist/

install: release
	cp .build/release/apple-contacts /usr/local/bin/

test:
	swift test
