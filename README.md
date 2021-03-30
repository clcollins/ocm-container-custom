# ocm-container-custom

Simple `Makefile` and `Dockerfile` to build [ocm-container](https://github.com/openshift/ocm-contianer) with the backplane-cli
and SRE utils from OPS-SOP. It can be easily extended or customized to add your own tools.

Please consider creating PRs upstream for things that may be useful to others, however.

## Usage

Source your ocm-container config (`source ~/.config/ocm-container/env.source`) and then build the container image ocm-container:latest with backplane and SRE tools by running the command `make`:

```shell
# Build ocm-container with backplane-cli and SRE tooling
$ source ~/.config/ocm-container/env.source
$ make
```
