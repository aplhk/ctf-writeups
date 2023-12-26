// Copyright 2023 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// Hello is a hello, world program, demonstrating
// how to write a simple command-line program.
//
// Usage:
//
//	hello [options] [name]
//
// The options are:
//
//	-g greeting
//		Greet with the given greeting, instead of "Hello".
//
//	-r
//		Greet in reverse.
//
// By default, hello greets the world.
// If a name is specified, hello greets that name instead.
package main

import (
	"flag"
	"fmt"
	"log"
	"os"
	"github.com/beltran/gohive"
	"context"
)

func usage() {
	fmt.Fprintf(os.Stderr, "usage: gohive [options] [name]\n")
	flag.PrintDefaults()
	os.Exit(2)
}

var (
	host = flag.String("h", "hive", "host")
	port = flag.Int("p", 10000, "port")
	username = flag.String("u", "root", "username")
	password = flag.String("pw", "", "password")
)

func main() {
	// Configure logging for a command-line program.
	log.SetFlags(0)
	log.SetPrefix("hihi: ")

	// Parse flags.
	flag.Usage = usage
	flag.Parse()

	// Parse and validate arguments.
	sql := []string{"select '12312'"}
	args := flag.Args()
	if len(args) >= 1 {
		sql = args
	}

	
	ctx := context.Background()

	configuration := gohive.NewConnectConfiguration()
	configuration.Service = "hive"
	configuration.TransportMode = "binary"
	configuration.Username = *username
	configuration.Password = *password

    connection, errConn := gohive.Connect(*host, *port, "NONE", configuration)
    if errConn != nil {
        log.Fatal(errConn)
    }
	// async := false
	cursor := connection.Cursor()

	sss:
	for i, stmt := range sql {
		cursor.Exec(ctx, stmt)
		if cursor.Err != nil {
			// log.Println("E:", cursor.Err)
			continue
		}
	
		var s string
		for cursor.HasMore(ctx) {
			cursor.FetchOne(ctx, &s)
			if cursor.Err != nil {
				// log.Println("E:", cursor.Err)
				continue sss
			}
			log.Println(i, s)
		}
	}

	cursor.Close()
    connection.Close()







	// Run actual logic.
	// fmt.Printf("%s, %s!\n", *greeting, name)
}