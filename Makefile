TEST?=$$(go list ./... | grep -v /vendor/)
VETARGS?=-asmdecl -atomic -bool -buildtags -copylocks -methods -nilfunc -printf -rangeloops -shift -structtags -unsafeptr
EXTERNAL_TOOLS=\
	github.com/mitchellh/gox \
	golang.org/x/tools/cmd/cover \
	golang.org/x/tools/cmd/vet \
	github.com/tebeka/selenium

default: test

# bin generates the releaseable binaries for Vault
bin: generate
	@sh -c "'$(CURDIR)/scripts/build.sh'"

# dev creates binaries for testing Vault locally. These are put
# into ./bin/ as well as $GOPATH/bin
dev: generate
	@VAULT_DEV_BUILD=1 sh -c "'$(CURDIR)/scripts/build.sh'"

# test runs the unit tests and vets the code
test: generate
	VAULT_TOKEN= TF_ACC= go test $(TEST) $(TESTARGS) -timeout=120s -parallel=4

KILL_SELENIUM = @ ([ -e "/tmp/selenium.pid" ] && ($(GOPATH)/src/github.com/tebeka/selenium/selenium.sh stop ; rm /tmp/selenium.pid))

# needed for some testacc tests (google)
selenium:
	-$(KILL_SELENIUM)
	@$(GOPATH)/src/github.com/tebeka/selenium/selenium.sh start


# testacc runs acceptance tests
testacc: generate
	@if [ "$(TEST)" = "./..." ]; then \
		echo "ERROR: Set TEST to a specific package"; \
		exit 1; \
	fi
	-TF_ACC=1 go test -v $(TEST) $(TESTARGS) -timeout 45m
	$(KILL_SELENIUM)

# testrace runs the race checker
testrace: generate
	CGO_ENABLED=1 VAULT_TOKEN= TF_ACC= go test -race $(TEST) $(TESTARGS)

cover:
	./scripts/coverage.sh --html

# vet runs the Go source code static analysis tool `vet` to find
# any common errors.
vet:
	@go list -f '{{.Dir}}' ./... | grep -v /vendor/ \
		| grep -v '.*github.com/hashicorp/vault$$' \
		| xargs go tool vet ; if [ $$? -eq 1 ]; then \
			echo ""; \
			echo "Vet found suspicious constructs. Please check the reported constructs"; \
			echo "and fix them if necessary before submitting the code for reviewal."; \
		fi

# generate runs `go generate` to build the dynamically generated
# source files.
generate:
	go generate $(go list ./... | grep -v /vendor/)

# bootstrap the build by downloading additional tools
bootstrap:
	@for tool in  $(EXTERNAL_TOOLS) ; do \
		echo "Installing $$tool" ; \
		go get $$tool; \
	done

	$(GOPATH)/src/github.com/tebeka/selenium/selenium.sh download


.PHONY: bin default generate test vet bootstrap selenium
