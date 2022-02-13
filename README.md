# trino-on-kubernetes

## setup

```sh
kubectl create namespace trino
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

### hive-metastore

follow the [gradiant hive-metastore chart](https://github.com/Gradiant/bigdata-charts/tree/master/charts/hive-metastore) to install hive-metastore

```sh
helm repo add bigdata-gradiant https://gradiant.github.io/bigdata-charts/
```

```sh
helm upgrade --install my-hive-metastore bigdata-gradiant/hive-metastore -n trino -f hive-metastore/values.yaml
```

verify the installation

```sh
kubectl run my-postgresql-client --rm --tty -i --restart='Never' --namespace trino --image docker.io/bitnami/postgresql:14.1.0-debian-10-r80 --env="PGPASSWORD=hive" -- psql --host my-hive-metastore-postgresql -U hive -d metastore -p 5432 -c "\dt"
```

```sh
                 List of relations
 Schema |           Name            | Type  | Owner
--------+---------------------------+-------+-------
 public | BUCKETING_COLS            | table | hive
 public | CDS                       | table | hive
 public | COLUMNS_V2                | table | hive
 public | DATABASE_PARAMS           | table | hive
 public | DBS                       | table | hive
 public | DB_PRIVS                  | table | hive
 public | DELEGATION_TOKENS         | table | hive
 public | FUNCS                     | table | hive
 public | FUNC_RU                   | table | hive
 public | GLOBAL_PRIVS              | table | hive
 public | IDXS                      | table | hive
 public | INDEX_PARAMS              | table | hive
 ...
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
     --env MINIO_SERVER_ROOT_USER=minio_accesss_key \
     --env MINIO_SERVER_ROOT_PASSWORD=minio_secret_key \
     --env MINIO_SERVER_HOST=my-minio \
     --image docker.io/bitnami/minio-client:2022.2.7-debian-10-r0 -- admin info minio
```

```sh
●  my-minio:9000
   Uptime: 7 minutes
   Version: 2022-02-07T08:17:33Z
   Network: 1/1 OK

0 B Used, 1 Bucket, 0 Objects
```

### trino

follow the [trino official chart](https://github.com/trinodb/charts/tree/main) to install trino

```sh
helm repo add trino https://trinodb.github.io/charts/
```

```sh
helm upgrade --install my-trino trino/trino --version 0.3.0 --namespace trino -f trino/values.yaml
```

verify the installation

```sh
kubectl exec -it deploy/my-trino-coordinator -n trino -- trino
```

in the trino shell

```sh
SHOW CATALOGS;

  Catalog
------------
 postgresql
 system
 tpcds
 tpch
(4 rows)
```

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

## Cleanup

```sh
helm uninstall my-trino -n trino
helm uninstall my-postgresql -n trino
helm uninstall my-hive-metastore -n trino
helm uninstall my-minio -n trino
kubectl delete pvc --all -n trino
kubectl delete namespace trino
```
