ARG TERRAFORM_VERSION
FROM hashicorp/terraform:${TERRAFORM_VERSION}

ARG TF_PLUGIN_CACHE_DIR

RUN mkdir -p ${TF_PLUGIN_CACHE_DIR}
ENV TF_PLUGIN_CACHE_DIR ${TF_PLUGIN_CACHE_DIR}

RUN apk add --no-cache bash go

COPY ./test/go.mod ./test/go.mod
COPY ./test/go.sum ./test/go.sum

RUN cd test && go mod download -x

COPY . .

# warm the cache so that parallel tests do not download the same providers multiple times
RUN cd examples && for e in *; do (cd $e && terraform init) ; done

ENTRYPOINT ["./docker/entrypoint.sh"]