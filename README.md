# Database_Exporter

## 概述

[Database_Exporter](https://github.com/xshrim/database_exporter)是一个开箱即用的基于Prometheus的配置驱动的DBMS数据库指标采集器. Database_Exporter采用Golang编写, 基于[Corundex/database_exporter](https://github.com/Corundex/database_exporter)进行轻度二次开发, 支持MySQL, PostgreSQL, Oracle DB, Microsoft SQL Server , Clickhouse, Couchbase和Sqlite3, 支持Golang sql驱动的其他DBMS数据库也能够通过添加驱动进行支持.

Exporter采集的所有指标和相应的SQL查询语句都是通过配置文件进行定义的. 指标查询SQL语句通过**collector**进行逻辑分组, collector可以直接定义在总配置文件(默认database_exporter.yaml)中, 也可以通过在总配置文件中include的方式定义在单独的文件中.

根据Prometheus的理念, 指标抓取是同步的(每次`/metrics`请求都会收集指标), 但为了将负载保持在合理的水平, 可以选择为每个收集器设置最小收集间隔, 当查询频率高于配置的间隔时, 会生成缓存的指标.

由于Oracle驱动[godror](https://github.com/godror/godror)运行时依赖[Oracle Instant Client](https://www.oracle.com/database/technologies/instant-client/downloads.html), 因此要求对于Oracle数据库的指标采集, 需要运行机上安装号Oracle Instant Client, 为避免麻烦, 建议通过预安装了Oracle Instant Client的容器的方式运行采集器.

## 用法

### 构建

```bash
make build   # 仅构建二进制文件
make package # 构建二进制文件并打包配置

docker build xshrim/database_exporter .   # 构建docker镜像
```

### 运行

```bash
./database_exporter # 二进制运行
docker run --rm -it -p 9285:9285 -v /root/database/database_exporter.yml:/exporter/database_exporter.yml -v /root/database/config/oracle_collectors:/exporter/config/oracle_collectors xshrim/database_exporter   # 容器运行(oracle)
```

使用 `-help` 查看命令帮助:

```bash
./database_exporter -help
```

```yaml
  -config.file string
      Database Exporter configuration file name. (default "database_exporter.yml", you can use sample oracle_exporter.yml, postgres_exporter.yml, mssql_exporter.yml or mysql_exporter.yml)
  -web.listen-address string
      Address to listen on for web interface and telemetry. (default ":9285")
  -web.metrics-path string
      Path under which to expose metrics. (default "/metrics")
  [...]
```

## 配置

Database Exporter与它从中收集指标的数据库服务器一起部署. 如果Exporter和数据库服务器位于同一主机上, 则它们将共享相同的故障域: 它们通常要么同时启动并运行, 要么同时关闭. 当数据库无法访问时， `/metrics` 以HTTP代码`500 Internal Server Error`进行响应, 导致Prometheus记录`up=0`该抓取. 只有exporter定义的指标才会在`/metrics`终端节点上导出. Database Exporter进程指标在`/database_exporter_metrics`中导出.

Database Exporter在`./config`目录下提供了默认所支持的DBMS数据库的通用采集配置, 同时在`./dashboard`下提供了对应采集配置的grafana dashboard.

### 全局配置

全局配置文件定义了抓取间隔, 数据库连接数, 抓取目标和使用的收集器等信息, 全局配置文件中可内联定义各收集器的采集指标, 也可单独include收集器文件, 或者二者混用

**`./database_exporter.yml`**

```yaml
# Global defaults.
global:
  # Subtracted from Prometheus' scrape_timeout to give us some headroom and prevent Prometheus from timing out first.
  scrape_timeout_offset: 500ms
  # Minimum interval between collector runs: by default (0s) collectors are executed on every scrape.
  min_interval: 0s
  # Maximum number of open connections to any one target. Metric queries will run concurrently on multiple connections,
  # as will concurrent scrapes.
  max_connections: 3
  # Maximum number of idle connections to any one target. Unless you use very long collection intervals, this should
  # always be the same as max_connections.
  max_idle_connections: 3

# The target to monitor and the collectors to execute on it.
target:
  # Data source name always has a URI schema that matches the driver name. In some cases (e.g. MySQL)
  # the schema gets dropped or replaced to match the driver expected DSN format.
  data_source_name: 'sqlite3://file::memory:?mode=memory&cache=shared'

  # Collectors (referenced by name) to execute on the target.
  collectors: [sqlite_metrics]

# Collector files specifies a list of globs. One collector definition is read from each matching file.
collector_files: 
  - "./config/sqlite_collectors/*.collector.yml"
```

完整的全局配置文件示例:

```yaml
# Global settings and defaults.
global:
  # Scrape timeouts ensure that:
  #   (i)  scraping completes in reasonable time and
  #   (ii) slow queries are canceled early when the database is already under heavy load
  # Prometheus informs targets of its own scrape timeout (via the "X-Prometheus-Scrape-Timeout-Seconds" request header)
  # so the actual timeout is computed as:
  #   min(scrape_timeout, X-Prometheus-Scrape-Timeout-Seconds - scrape_timeout_offset)
  #
  # If scrape_timeout <= 0, no timeout is set unless Prometheus provides one. The default is 10s.
  scrape_timeout: 10s
  # Subtracted from Prometheus' scrape_timeout to give us some headroom and prevent Prometheus from timing out first.
  #
  # Must be strictly positive. The default is 500ms.
  scrape_timeout_offset: 500ms
  # Minimum interval between collector runs: by default (0s) collectors are executed on every scrape.
  min_interval: 0s
  # Maximum number of open connections to any one target. Metric queries will run concurrently on multiple connections,
  # as will concurrent scrapes.
  #
  # If max_connections <= 0, then there is no limit on the number of open connections. The default is 3.
  max_connections: 3
  # Maximum number of idle connections to any one target. Unless you use very long collection intervals, this should
  # always be the same as max_connections.
  #
  # If max_idle_connections <= 0, no idle connections are retained. The default is 3.
  max_idle_connections: 3

# The target to monitor and the collectors to execute on it.
target:
  # Data source name always has a URI schema that matches the driver name. In some cases (e.g. MySQL)
  # the schema gets dropped or replaced to match the driver expected DSN format.
  data_source_name: 'sqlserver://prom_user:prom_password@dbserver1.example.com:1433'

  # Collectors (referenced by name) to execute on the target.
  collectors: [mssql_standard]

# A collector is a named set of related metrics that are collected together. It can be referenced by name, possibly
# along with other collectors.
#
# Collectors may be defined inline (under `collectors`) or loaded from `collector_files` (one collector per file).
collectors:
  # A collector defining standard metrics for Microsoft SQL Server.
  - collector_name: mssql_standard

    # Similar to global.min_interval, but applies to this collector only.
    #min_interval: 0s

    # A metric is a Prometheus metric with name, type, help text and (optional) additional labels, paired with exactly
    # one query to populate the metric labels and values from.
    #
    # The result columns conceptually fall into two categories:
    #  * zero or more key columns: their values will be directly mapped to labels of the same name;
    #  * one or more value columns:
    #     * if exactly one value column, the column name name is ignored and its value becomes the metric value
    #     * with multiple value columns, a `value_label` must be defined; the column name will populate this label and
    #       the column value will popilate the metric value.
    metrics:
      # The metric name, type and help text, as exported to /metrics.
      - metric_name: mssql_log_growths
        # This is a Prometheus counter (monotonically increasing value).
        type: counter
        help: 'Total number of times the transaction log has been expanded since last restart, per database.'
        # Optional set of labels derived from key columns.
        key_labels:
          # Populated from the `db` column of each row.
          - db
        # Static label value pairs
        static_labels:
          sys: ibp
        # This query returns exactly one value per row, in the `counter` column.
        values: [counter]
        query: |
          SELECT rtrim(instance_name) AS db, cntr_value AS counter
          FROM sys.dm_os_performance_counters
          WHERE counter_name = 'Log Growths' AND instance_name <> '_Total'

      # A different metric, with multiple values produced from each result row.
      - metric_name: mssql_io_stall_seconds
        type: counter
        help: 'Stall time in seconds per database and I/O operation.'
        key_labels:
          # Populated from the `db` column of the result.
          - db
        # Label populated with the value column name, configured via `values` (e.g. `operation="io_stall_read_ms"`).
        #
        # Required when multiple value columns are configured.
        value_label: operation
        # Multiple value columns: their name is recorded in the label defined by `attrubute_label` (e.g. 
        # `operation="io_stall_read_ms"`).
        values:
          - io_stall_read
          - io_stall_write
        query_ref: io_stall

      # Another metric, uses same named query (referenced through query_ref) as mssql_io_stall_seconds.
      - metric_name: mssql_io_stall_total_seconds
        type: counter
        help: 'Total stall time in seconds per database.'
        key_labels:
          # Populated from the `db` column of the result.
          - db
        # Only one value, populated from the `io_stall` column.
        values:
          - io_stall
        query_ref: io_stall

    # Named queries, referenced by one or more metrics, through query_ref.
    queries:
      # Populates `mssql_io_stall` and `mssql_io_stall_total`
      - query_name: io_stall
        query: |
          SELECT
            cast(DB_Name(a.database_id) as varchar) AS db,
            sum(io_stall_read_ms) / 1000.0 AS io_stall_read,
            sum(io_stall_write_ms) / 1000.0 AS io_stall_write,
            sum(io_stall) / 1000.0 AS io_stall
          FROM
            sys.dm_io_virtual_file_stats(null, null) a
          INNER JOIN sys.master_files b ON a.database_id = b.database_id AND a.file_id = b.file_id
          GROUP BY a.database_id

# Collector files specifies a list of globs. One collector definition per file.
collector_files: 
  - "*.collector.yml"

```

### 收集器

收集器可以在exporter配置文件中以内联方式定义, 也可以在`collectors`单独的文件中定义, 并在exporter配置中按名称引用, 从而使它们易于共享和重用.

**`./sqlite_collectors/sqlite.collector.yml`**

```yaml
# A collector defining standard metrics for SQLite.

collector_name: sqlite_metrics

# Similar to global.min_interval, but applies to the queries defined by this collector only.
#min_interval: 0s

metrics:
  - metric_name: dummy_metric_value
    type: gauge
    help: Sample query
    values:
      - value
    query: |
      select 1 as value

  - metric_name: sqlite_objects_rootpage
    type: gauge
    help: Sample query
    values:
      - rootpage
    key_labels:
      - name
      - tbl_name
      - type
    query: |
      SELECT
        rootpage,
        name,
        tbl_name,
        type
      FROM 
        sqlite_master
```

### 数据源

为了保持简单, 同时允许设置完全可配置的数据库连接, Database Exporter使用DSN(如`sqlserver://prom_user:prom_password@dbserver1.example.com:1433`) 来引用数据库实例. 但是, 由于Go `sql`库不允许基于DSN自动选择驱动程序(即必须指定显式驱动程序名称), 因此数据库导出程序使用DSN的架构部分(`://`之前的部分)来确定要使用的驱动程序.

虽然这适用于MS SQL Server和PostgreSQL驱动程序, 但Oracle OCI8和MySQL驱动程序DSN格式不包含schema, 而Clickhouse使用`tcp://`. 因此Database Exporter对后两个驱动程序的DSN进行了一些处理, 以便使其正常工作:

| DB                 | Database Exporter expected DSN                                                              | Driver sees                                                  |
| :----------------- | :------------------------------------------------------------------------------------------ | :----------------------------------------------------------- |
| MySQL              | `mysql://user:passw@protocol(host:port)/dbname`                                           | `user:passw@protocol(host:port)/dbname`                    |
| Oracle             | `oracle://user/password@host:port/sid`                                                    | `user/password@host:port/sid`                              |
| PostgreSQL         | `postgres://user:passw@host:port/dbname`                                                  | *unchanged*                                                |
| SQL Server         | `sqlserver://user:passw@host:port/instance`                                               | *unchanged*                                                |
| SQLite3            | `sqlite3://file:mybase.db?cache=shared&mode=rwc`                                          | `file:mybase.db?cache=shared&mode=rwc`                     |
| in-memory SQLite3  | `sqlite3://file::memory:?mode=memory&cache=shared`                                        | `file::memory:?mode=memory&cache=shared`                   |
| Clickhouse         | `clickhouse://host:port?username=user&password=passw&database=db`                         | `tcp://host:port?username=user&password=passw&database=db` |
| Couchbase instance | `n1ql://host:port@creds=[{"user":"Administrator","pass":"admin123"}]@timeout=10s`         | `host:port`                                                |
| Couchbase cluster  | `n1ql://http://host:port/@creds=[{"user":"Administrator","pass":"admin123"}]@timeout=10s` | `http://host:port/`                                        |
