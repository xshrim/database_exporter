# Copyright 2015 The Prometheus Authors
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

GO    := go
pkgs   = ./
package_name = database_exporter
GOOS = linux
GOARCH = amd64

PREFIX              ?= $(shell pwd)
BIN_DIR             ?= $(shell pwd)
DOCKER_IMAGE_NAME   ?= database_exporter
DOCKER_IMAGE_TAG    ?= $(subst /,-,$(shell git rev-parse --abbrev-ref HEAD))


all: format build test

style:
	@echo ">> checking code style"
	@! gofmt -d $(shell find . -path ./vendor -prune -o -name '*.go' -print) | grep '^'

test:
	@echo ">> running tests"
	@$(GO) test -short -race $(pkgs)

format:
	@echo ">> formatting code"
	@$(GO) fmt $(pkgs)

vet:
	@echo ">> vetting code"
	@$(GO) vet $(pkgs)

build:
	@echo ">> building binaries"
	@GOOS=$(GOOS) GOARCH=$(GOARCH) $(GO) build -a -tags netgo -o $(package_name)

xgo:
	@(GO) get github.com/karalabe/xgo
	@xgo --targets=linux/amd64,windows/amd64,darwin/amd64 github.com/xshrim/database_exporter

package: build
	@echo ">> packaging release tarball"
	@tar -zcvf $(package_name).tgz $(package_name) $(package_name).yml config

tarball: promu
	@echo ">> building release tarball"
	@$(PROMU) tarball --prefix $(PREFIX) $(BIN_DIR)

docker:
	@echo ">> building docker image"
	@docker build -t "$(DOCKER_IMAGE_NAME):$(DOCKER_IMAGE_TAG)" .

.PHONY: all style format build test vet tarball docker promu
