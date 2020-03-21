SRC=.
DST=nornir-automation.github.io

HUGO_VERSION=v0.65.3
DOCKER_HUGO=docker run \
	 -it \
	-v $(PWD):/nornir.tech \
	-p 1313:1313 \
	nornir.tech:latest

HUGO_OPTS=--source $(SRC) --destination $(DST)
HUGO_TEST_OPTS=-D -E -F --disableFastRender --bind 0.0.0.0

.PHONY: docker-image
docker-image:
	docker build \
		--build-arg HUGO_VERSION=$(HUGO_VERSION) \
		--build-arg USER=$(shell id -un) \
		--build-arg USERID=$(shell id -u) \
		--build-arg GROUP=$(shell id -gn) \
		--build-arg GROUPID=$(shell id -g) \
		-t nornir.tech:latest \
		-f Dockerfile \
		.

.PHONY: serve
serve: clean
	hugo serve \
		$(HUGO_TEST_OPTS) \
		$(HUGO_OPTS)

.PHONY: gen
gen: clean
	hugo \
		$(HUGO_OPTS)

.PHONY: docker-serve
docker-serve: clean
	$(DOCKER_HUGO) make serve

.PHONY: docker-gen
docker-gen: clean
	$(DOCKER_HUGO) make gen

.PHONY: clean
clean:
	cd $(DST) && \
	find  -maxdepth 1 -not \(\
		-name '.*' -or \
		-name 'CNAME' -or \
		\) -print0 | xargs -0  -I {} rm -rf {}
