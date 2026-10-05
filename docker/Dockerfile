ARG TERRAFORM_VERSION
FROM hashicorp/terraform:${TERRAFORM_VERSION}

ARG TF_PLUGIN_CACHE_DIR

RUN mkdir -p ${TF_PLUGIN_CACHE_DIR}
ENV TF_PLUGIN_CACHE_DIR ${TF_PLUGIN_CACHE_DIR}

RUN apk add --no-cache bash

COPY . .

# warm the cache so terraform init/validate don't re-download providers for every example
RUN cd examples && for e in *; do (cd $e && terraform init) ; done

ENTRYPOINT ["./docker/entrypoint.sh"]