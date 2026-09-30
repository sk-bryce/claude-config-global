package main

import (
	"flag"
	"fmt"
	"os"
)

func main() {
	config := flag.String("config", "/etc/notectl/notectl.toml", "path to the config file")
	verbose := flag.Bool("verbose", false, "print the config file in use at start")
	flag.Parse()

	if *verbose {
		fmt.Fprintf(os.Stderr, "notectl: using config %s\n", *config)
	}
	fmt.Println("notectl ready")
}
