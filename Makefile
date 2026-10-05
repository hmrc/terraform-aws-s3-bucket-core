.ONESHELL:
SHELL = /bin/bash
.SHELLFLAGS = -euo pipefail -c
DEV_DOCKER_ARGS = --volume "$(PWD):$(PWD):z" --workdir "$(PWD)" --interactive --rm
CONDITIONAL_DOCKER_ARGS := $(if $(CI_MODE),,$(DEV_DOCKER_ARGS))

DOCKER = docker build \
    --file docker/Dockerfile \
    --build-arg TERRAFORM_VERSION=$$(head -n1 examples/.terraform-version) \
    --build-arg TF_PLUGIN_CACHE_DIR="/var/tf_cache_dir" \
    --tag test-run:ci . \
    && docker run \
    --env AWS_ACCESS_KEY_ID \
    --env AWS_SECRET_ACCESS_KEY \
    --env AWS_SESSION_TOKEN \
    --env AWS_SECURITY_TOKEN \
    --env AWS_REGION \
    $(CONDITIONAL_DOCKER_ARGS) \
     test-run:ci

.PHONY: $(MAKECMDGOALS)

fmt:
	$(DOCKER) terraform fmt -recursive .

fmt-check:
	$(DOCKER) terraform fmt --recursive --check .

validate:
	$(DOCKER) "terraform -chdir=examples/simple init -backend=false -reconfigure -input=false && terraform -chdir=examples/simple validate"

