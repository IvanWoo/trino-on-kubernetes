# trino-on-kubernetes <!-- omit in toc -->

Trino is a federated query engine, the connector-based architecture makes it easy to integrate with other systems.

In this repo, we are using the [Kubernetes](https://kubernetes.io/) to deploy the Trino service and other systems.

- [prerequisites](#prerequisites)
- [setup](#setup)
  - [namespace](#namespace)
  - [postgresql](#postgresql)
  - [minio](#minio)
  - [hive-metastore](#hive-metastore)
    - [hive-metastore-postgresql](#hive-metastore-postgresql)
    - [hive-metastore](#hive-metastore-1)
  - [clickhouse](#clickhouse)
  - [redis](#redis)
  - [trino](#trino)
- [playground](#playground)
  - [blackhole connector](#blackhole-connector)
  - [postgresql connector](#postgresql-connector)
  - [hive connector](#hive-connector)
  - [clickhouse connector](#clickhouse-connector)
- [cleanup](#cleanup)
- [references](#references)


## prerequisites
- [Rancher Desktop](https://github.com/rancher-sandbox/rancher-desktop): `1.2.1`
- Kubernetes: `v1.22.6`
- kubectl `v1.23.3`
- Helm: `v3.7.2`


## setup

tl;dr: `bash scripts/up.sh`

### namespace

```sh
kubectl create namespace trino --dry-run=client -o yaml | kubectl apply -f -
```

### postgresql

follow the [bitnami postgresql chart](https://github.com/bitnami/charts/tree/master/bitnami/postgresql) to install postgresql

```sh
helm repo add bitnami https://charts.bitnami.com/bitnami
```

```sh
helm upgrade --install my-postgresql bitnami/postgresql -n trino -f postgresql/values.yaml
```

verify the installation

```sh
kubectl run my-postgresql-client --rm --tty -i --restart='Never' --namespace trino --image docker.io/bitnami/postgresql:14.1.0-debian-10-r80 --env="PGPASSWORD=trino_demo_password" -- psql --host my-postgresql -U trino_demo_user -d trino_demo -p 5432 -c "\dt"
```

```sh
            List of relations
 Schema | Name  | Type  |      Owner
--------+-------+-------+-----------------
 public | users | table | trino_demo_user
(1 row)
```

### minio

follow the [bitnami minio chart](https://github.com/bitnami/charts/tree/master/bitnami/minio) to install minio

```sh
helm repo add bitnami https://charts.bitnami.com/bitnami
```

```sh
helm upgrade --install my-minio bitnami/minio -n trino -f minio/values.yaml
```

verify the installation

```sh
kubectl run --namespace trino my-minio-client \
     --rm --tty -i --restart='Never' \
     --env MINIO_SERVER_ROOT_USER=minio_access_key \
     --env MINIO_SERVER_ROOT_PASSWORD=minio_secret_key \
     --env MINIO_SERVER_HOST=my-minio \
     --image docker.io/bitnami/minio-client:2022.2.7-debian-10-r0 -- admin info minio
```

```sh
●  my-minio:9000
   Uptime: 7 minutes
   Version: 2022-02-07T08:17:33Z
   Network: 1/1 OK

0 B Used, 2 Buckets, 0 Objects
```

### hive-metastore

#### hive-metastore-postgresql

follow the [bitnami postgresql chart](https://github.com/bitnami/charts/tree/master/bitnami/postgresql) to install postgresql for hive-metastore

```sh
helm repo add bitnami https://charts.bitnami.com/bitnami
```

```sh
helm upgrade --install hive-metastore-postgresql bitnami/postgresql -n trino -f hive-metastore-postgresql/values.yaml
```

verify the installation

```sh
kubectl run hive-metastore-postgresql-client --rm --tty -i --restart='Never' --namespace trino --image docker.io/bitnami/postgresql:14.1.0-debian-10-r80 --env="PGPASSWORD=admin" -- psql --host hive-metastore-postgresql -U admin -d metastore_db -p 5432 -c "\du"
```

```sh
                                   List of roles
 Role name |                         Attributes                         | Member of
-----------+------------------------------------------------------------+-----------
 admin     | Create DB                                                  | {}
 postgres  | Superuser, Create role, Create DB, Replication, Bypass RLS | {}
```

#### hive-metastore

using the helm chart (based on the [gradiant hive-metastore chart](https://github.com/Gradiant/bigdata-charts/tree/master/charts/hive-metastore)) to install hive-metastore

```sh
helm upgrade --install my-hive-metastore -n trino -f hive-metastore/values.yaml ./charts/hive-metastore
```

verify the installation

```sh
kubectl run hive-metastore-postgresql-client --rm --tty -i --restart='Never' --namespace trino --image docker.io/bitnami/postgresql:14.1.0-debian-10-r80 --env="PGPASSWORD=admin" -- psql --host hive-metastore-postgresql -U admin -d metastore_db -p 5432 -c "\dt"
```

```sh
                   List of relations
 Schema |             Name              | Type  | Owner
--------+-------------------------------+-------+-------
 public | BUCKETING_COLS                | table | admin
 public | CDS                           | table | admin
 public | COLUMNS_V2                    | table | admin
 public | CTLGS                         | table | admin
 public | DATABASE_PARAMS               | table | admin
 public | DBS                           | table | admin
 public | DB_PRIVS                      | table | admin
 public | DELEGATION_TOKENS             | table | admin
 public | FUNCS                         | table | admin
 public | FUNC_RU                       | table | admin
 public | GLOBAL_PRIVS                  | table | admin
...
```

### clickhouse

follow the [altinity clickhouse operator](https://github.com/Altinity/clickhouse-operator) to install clickhouse

install the Custom Resource Definition(crd)

```sh
kubectl apply -f https://raw.githubusercontent.com/Altinity/clickhouse-operator/master/deploy/operator/clickhouse-operator-install-bundle.yaml
```

the following results are expected

```sh
customresourcedefinition.apiextensions.k8s.io/clickhouseinstallations.clickhouse.altinity.com created
customresourcedefinition.apiextensions.k8s.io/clickhouseinstallationtemplates.clickhouse.altinity.com created
customresourcedefinition.apiextensions.k8s.io/clickhouseoperatorconfigurations.clickhouse.altinity.com created
serviceaccount/clickhouse-operator created
clusterrole.rbac.authorization.k8s.io/clickhouse-operator-kube-system created
clusterrolebinding.rbac.authorization.k8s.io/clickhouse-operator-kube-system created
configmap/etc-clickhouse-operator-files created
configmap/etc-clickhouse-operator-confd-files created
configmap/etc-clickhouse-operator-configd-files created
configmap/etc-clickhouse-operator-templatesd-files created
configmap/etc-clickhouse-operator-usersd-files created
deployment.apps/clickhouse-operator created
service/clickhouse-operator-metrics created
```

verify the installation

```sh
kubectl get pods --namespace kube-system
```

```sh
NAME                                      READY   STATUS      RESTARTS        AGE
...
clickhouse-operator-78f59f855b-pqntt      2/2     Running     0               57s
...
```

install the clickhouse via the operator

```sh
kubectl apply -f clickhouse/ -n trino
```

verify the installation

```sh
kubectl exec chi-bootstrap-bootstrap-0-0-0 -n trino -- clickhouse-client -u analytics --password admin --query="SHOW DATABASES"
```

```sh
INFORMATION_SCHEMA
default
information_schema
psql
system
```

### redis

follow the [bitnami redis chart](https://github.com/bitnami/charts/tree/master/bitnami/redis) to install redis

```sh
helm repo add bitnami https://charts.bitnami.com/bitnami
```

```sh
helm upgrade --install my-redis bitnami/redis -n trino -f redis/values.yaml
```

verify the installation

```sh
kubectl exec -it svc/my-redis-master -n trino -- redis-cli -h my-redis-master -a trino_demo_password scan 0
```

```sh
Warning: Using a password with '-a' or '-u' option on the command line interface may not be safe.
1) "0"
2) (empty array)
```

create the redis table definition config-map

```sh
kubectl create secret generic redis-table-definition --from-file=redis/test.json -n trino
```


### trino

follow the [trino official chart](https://github.com/trinodb/charts/tree/main) to install trino

```sh
helm repo add trino https://trinodb.github.io/charts/
```

```sh
helm upgrade --install my-trino trino/trino --version 0.7.0 --namespace trino -f trino/values.yaml
```

verify the installation

```sh
kubectl exec -it deploy/my-trino-coordinator -n trino -- trino
```

## playground

all of the sql is running in the trino shell

```sh
kubectl exec -it deploy/my-trino-coordinator -n trino -- trino
```

```sh
SHOW CATALOGS;

  Catalog   
------------
 blackhole  
 clickhouse 
 minio      
 postgresql 
 redis      
 system     
 tpcds      
 tpch       
(8 rows)
```

### blackhole connector

```sh
CREATE SCHEMA blackhole.test;
CREATE TABLE blackhole.test.orders AS SELECT * FROM tpch.tiny.orders;
INSERT INTO blackhole.test.orders SELECT * FROM tpch.sf3.orders;
```

### postgresql connector

```sh
SHOW SCHEMAS IN postgresql;

       Schema
--------------------
 information_schema
 pg_catalog
 public
(3 rows)
```

Using the PostgreSQL connector, Trino is able to retrieve the data for processing, returning the results to the user

```sh
SELECT * FROM postgresql.public.users LIMIT 10;

 id |          hash_firstname          |          hash_lastname           | gender
----+----------------------------------+----------------------------------+--------
  1 | f5dc053c6a990f0a8d0bad6f24236b70 | 5761f0e5541fb97d00fa27e987def570 | male
  2 | a6d8c2b879fe12f6ebf1c31e9d61ee19 | 4987f98516d2ea3e5a7a4a9e55961aaa | male
  3 | 9b9151d6171c542f01b287101d64c5cf | 0f2709bd076510b6259fa577b60656f9 | male
  4 | 372a1003b9b9d07b8b1810c7d8046f3a | d2c162c6420fdbc365606fff9c13d15f | female
  5 | c89cf3fd694b06be6fd57266fa837270 | 5a8276209f43e15c5b033319fc771e61 | male
  6 | f6aa6c81e3e028a026b31e81ec67bbaf | 1f93f485076e4836deb62989f14c6479 | male
  7 | 036e653a0e2ff8ed7739321abf292c99 | e0ebaf4e12f9baccc8b2f81701d0ec6d | female
  8 | 3015ff27051f1c6a28c6f1fe4fb0a5d9 | 5a51726736d652c7c29f893594feb635 | female
  9 | b16c10f0095e21667959bca5e40d982a | 8da0d3afc36dbb79435d80731cb81fc6 | female
 10 | 4a97230b2c83d6964534762ae92687be | f4a61b78eac4e2a23a595a38145304eb | female
(10 rows)
```

### hive connector

follow [Hive connector over MinIO file storage tutorial](https://github.com/bitsondatadev/trino-getting-started/tree/main/hive/trino-minio) to test the hive connector

```sh
SHOW SCHEMAS IN minio;
```

```sh
       Schema
--------------------
 default
 information_schema
```

```sh
CREATE SCHEMA minio.tiny
WITH (location = 's3a://tiny/');
```

```sh
CREATE TABLE minio.tiny.customer
WITH (
    format = 'ORC',
    external_location = 's3a://tiny/customer/'
) 
AS SELECT * FROM tpch.tiny.customer;
```

```sh
SELECT * FROM minio.tiny.customer LIMIT 50;
```

```sh
SHOW SCHEMAS IN minio;
```

```sh
       Schema
--------------------
 default
 information_schema
 tiny
(3 rows)
```

### clickhouse connector

```sh
SHOW SCHEMAS IN clickhouse;
```

```sh
       Schema
--------------------
 default
 information_schema
 psql
 system
(4 rows)
```

no data in the clickhouse

```sh
SELECT * FROM clickhouse.psql.users limit 10;
```

```sh
 hash_firstname | hash_lastname | gender
----------------+---------------+--------
(0 rows)
```

insert from postgresql.public.users 

```sh
INSERT INTO clickhouse.psql.users
SELECT
  to_utf8(hash_firstname),
  to_utf8(hash_lastname),
  to_utf8(gender)
FROM postgresql.public.users;
```

```sh
SELECT
  from_utf8(hash_firstname) as hash_firstname,
  from_utf8(hash_lastname) as hash_lastname,
  from_utf8(gender) as gender
FROM clickhouse.psql.users limit 10;
```

```sh
          hash_firstname          |          hash_lastname           | gender
----------------------------------+----------------------------------+--------
 aed49d619bcf829c41d29bf48d2d5825 | 0d4795a498e0baf87fe0aecd627a960a | female
 97b8e38f05d19fe1b8759aaa583b3623 | dd7cb0aa18092f1ed205aab78a01ca63 | male
 ef22320d1409546ec11de4b0e3a2968e | 092edfd88d68340ea4dbbff1a7a20f07 | male
 3a74c6efbf66f00e9d944e41f3edb6da | 42f3b109c6c224d07347adfcb697cddc | female
 9b5ef82415b32b2c2b3b7fd12ecc1279 | fa2a6cf03fdecb863f337fd5af413358 | male
 dd616a7291150e07214355d5443297ac | 0133d5f34a48c31b4f80aec84a8f4ca7 | female
 bc44e7cbae828d2829831f9d2efdbff7 | 9a96db30be5bd5e2d653b5d37d8a7592 | female
 b3a46696e4c089742123d9cc6e4bf901 | 8d99a00cbc440d71709cc6fba8d3f605 | male
 ca5e93ecd5729eb0a40814aca7de80f3 | 052ba042b4cfe29bd5fb040dbb58ad88 | female
 eb2544b415fc7440bd727ad7790741ef | b58736031ae630b4e1266ab359f33a35 | female
```

## redis connector

```sh
SHOW SCHEMAS IN redis;
```

```sh
       Schema       
--------------------
 information_schema 
 trino              
(2 rows)
```

```sh
SHOW COLUMNS IN redis.default.test;
```

```sh
 Column |  Type   | Extra | Comment 
--------+---------+-------+---------
 number | integer |       |         
(1 row)
```

save some test data in the redis

```sh
kubectl exec -it svc/my-redis-master -n trino -- redis-cli -h my-redis-master -a trino_demo_password set test '{"number": 20}'
```

read from trino

```sh
SELECT * FROM redis.default.test LIMIT 10;
```

```sh
 number 
--------
     20 
(1 row)
```

## cleanup

tl;dr: `bash scripts/down.sh`

```sh
helm uninstall my-trino -n trino
helm uninstall my-redis -n trino
helm uninstall my-postgresql -n trino
helm uninstall my-hive-metastore -n trino
helm uninstall hive-metastore-postgresql -n trino
helm uninstall my-minio -n trino
kubectl delete -f clickhouse/ -n trino
kubectl delete -f https://raw.githubusercontent.com/Altinity/clickhouse-operator/master/deploy/operator/clickhouse-operator-install-bundle.yaml
kubectl delete pvc --all -n trino
kubectl delete namespace trino
```

## references
- [realtimedatalake/hive-metastore-docker: Containerized Apache Hive Metastore for horizontally scalable Hive Metastore deployments](https://github.com/realtimedatalake/hive-metastore-docker)
- [liangjingyang/hive-metastore](https://github.com/liangjingyang/hive-metastore/commit/112ce99241f5b68d9f45b775ce49e0550634c194)
- [Gradiant/bigdata-charts: charts/hive-metastore](https://github.com/Gradiant/bigdata-charts/tree/master/charts/hive-metastore)
- [bitsondatadev/trino-getting-started: Hive connector over MinIO file storage](https://github.com/bitsondatadev/trino-getting-started/tree/main/hive/trino-minio)
- [bitsondatadev/hive-metastore: entrypoint.sh](https://github.com/bitsondatadev/hive-metastore/blob/master/scripts/entrypoint.sh)