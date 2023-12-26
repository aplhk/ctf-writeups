# Hive custom User Defined Function(UDF)

Hive supports plenty of built-in SQL-like functions in HiveQL. But just in case, if there is a need to write our own UDF, we can write the same in Java.

## Implementation steps

1. Create a Java class for User Defined Function by extending ```org.apache.hadoop.hive.ql.exec.UDF``` class and implement one or more evaluate() methods and put our desired logic in that method.
2. Package Java class into JAR file.
3. Go to Hive CLI – ADD the packaged JAR using ```ADD JAR``` command.
4. CREATE TEMPORARY FUNCTION in hive which points to the custom UDF Java class.
5. Use this function in a regular Hive query.

System Requirements:

* Operating System : Any(Windows/Linux/Mac)
* Java : JDK1.8
* Build Tool: Maven
* IDE used: Eclipse

## Compile

```
mvn compile
```

## Test

```
mvn test
```

## Package
```
mvn clean package
```

## Run

```
%> hive
hive> ADD JAR /home/sakthiinfotec/hive-custom-udfs-0.0.1-SNAPSHOT.jar;
hive> CREATE TEMPORARY FUNCTION toUpperCase as 'com.sakthiinfotec.hive.custom.ToUpperCaseUDF';
hive> SELECT toUpperCase(first_name) FROM users LIMIT 25;
```
