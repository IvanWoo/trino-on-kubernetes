#!/bin/sh
# This file is autogenerated - DO NOT EDIT!

set -euo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="${BASE_DIR}/.."
(
cd ${REPO_DIR}
kubectl create namespace trino --dry-run=client -o yaml | kubectl apply -f -
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add trino https://trinodb.github.io/charts/
helm upgrade --install my-postgresql bitnami/postgresql -n trino -f postgresql/values.yaml
helm upgrade --install my-minio bitnami/minio -n trino -f minio/values.yaml
helm upgrade --install hive-metastore-postgresql bitnami/postgresql -n trino -f hive-metastore-postgresql/values.yaml
helm upgrade --install my-hive-metastore -n trino -f hive-metastore/values.yaml ./charts/hive-metastore
helm upgrade --install my-trino trino/trino --version 0.4.0 --namespace trino -f trino/values.yaml
)
