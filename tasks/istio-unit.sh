#!/bin/bash
set -euxo pipefail

mkdir -p go/bin
export GOPATH=$PWD/go

ln -s "$(which etcd)" "$GOPATH/bin/etcd"

# TODO: perhaps envoy can be a separate resource
mkdir envoy
pushd envoy
  ISTIO_PROXY_BUCKET=$(sed 's/ = /=/' <<< $( awk '/ISTIO_PROXY_BUCKET =/' $GOPATH/src/istio.io/istio/WORKSPACE))
  PROXYVERSION=$(sed 's/[^"]*"\([^"]*\)".*/\1/' <<<  $ISTIO_PROXY_BUCKET)
  PROXY=debug-$PROXYVERSION
  wget -qO- https://storage.googleapis.com/istio-build/proxy/envoy-$PROXY.tar.gz | tar xvz
  envoy_bin=$PWD/usr/local/bin/envoy
popd

cd $GOPATH/src/istio.io/istio
ln -sf $envoy_bin $PWD/pilot/proxy/envoy/envoy

ln -s $PWD/.circleci/config $PWD/pilot/platform/kube/config
ln -s $PWD/.circleci/config $PWD/pilot/platform/kube/inject/config
ln -s $PWD/.circleci/config $PWD/pilot/platform/kube/admit/config
ln -s $PWD/.circleci/config $PWD/broker/pkg/platform/kube/config

time dep ensure

/tmp/apiserver/start-test-server.sh > /dev/null 2>&1 &
sleep 5 # for server to start

go test ./pilot/...
go test ./security/...
go test ./broker/...
