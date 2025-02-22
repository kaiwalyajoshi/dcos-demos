#!/bin/bash

set -eof pipefail

SERVICE_ACCOUNT_NAME=dklb-principal

BASE64_ARGS="-w 0"
# base64 on macosx doesn't require any command line parameters
if [[ "$OSTYPE" == "darwin"* ]]; then
  BASE64_ARGS=
fi

if ! dcos security org service-accounts show "${SERVICE_ACCOUNT_NAME}" &>/dev/null; then
  # create service account
  dcos security org service-accounts keypair dklb-private-key.pem dklb-public-key.pem
  dcos security org service-accounts create -p dklb-public-key.pem -d "dklb service account" ${SERVICE_ACCOUNT_NAME}
  ./delete-secret.sh ${SERVICE_ACCOUNT_NAME}/sa
  dcos security secrets create-sa-secret dklb-private-key.pem ${SERVICE_ACCOUNT_NAME} ${SERVICE_ACCOUNT_NAME}/sa

  # grant the possibility to manage and list the secrets
  dcos security org users grant dklb-principal dcos:secrets:default:/* create
  dcos security org users grant dklb-principal dcos:secrets:default:/${SERVICE_ACCOUNT_NAME}/* full
  dcos security org users grant dklb-principal dcos:secrets:list:default:/${SERVICE_ACCOUNT_NAME} read
fi

if ! kubectl -n kube-system get secret dklb-dcos-config &>/dev/null; then
  # extract the service account secret from the json response
  SERVICE_ACCOUNT_SECRET=$(dcos security secrets get /${SERVICE_ACCOUNT_NAME}/sa --json | jq -r .value | base64 ${BASE64_ARGS} -)

# create a kubernetes secret with the dcos service account secret
kubectl create --kubeconfig=../core/config.$1 -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: dklb-dcos-config
  namespace: kube-system
type: Opaque
data:
  serviceAccountSecret: "${SERVICE_ACCOUNT_SECRET}"
EOF

fi
