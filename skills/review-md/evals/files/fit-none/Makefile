BINARY := notectl

.PHONY: build test dev clean

build:
	go build -o bin/$(BINARY) ./cmd/notectl

test:
	go test ./...

dev:
	go run ./cmd/notectl --config config/dev.toml --verbose

clean:
	rm -rf bin
