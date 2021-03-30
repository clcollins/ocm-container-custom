# ocm-container-custom

Simple `Makefile` and `Containerfile` to build [ocm-container](https://github.com/openshift/ocm-contianer) with the backplane-cli
and SRE utils from OPS-SOP. It can be easily extended or customized to add your own tools.

Please consider creating PRs upstream for things that may be useful to others, however.

## Usage

```shell
# Build the container image ocm-container:latest with backplane and SRE tools
$ make
```

