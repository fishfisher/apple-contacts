.PHONY: build clean test release

build:
	go build -o apple-contacts .

clean:
	rm -f apple-contacts
	rm -rf dist/

test:
	go test ./...

release:
	goreleaser release --clean
