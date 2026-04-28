// slap-to-yes detects physical slaps on Apple Silicon MacBooks via the
// IMU and presses Enter, so your AI coding assistant's "(y/N)" prompts
// stop interrupting your flow.
package main

import (
	"fmt"
	"os"
)

const version = "0.1.0-dev"

func main() {
	if len(os.Args) < 2 {
		usage(os.Stderr)
		os.Exit(2)
	}

	switch os.Args[1] {
	case "doctor":
		os.Exit(cmdDoctor(os.Args[2:]))
	case "run":
		os.Exit(cmdRun(os.Args[2:]))
	case "version", "-v", "--version":
		fmt.Println("slap-to-yes", version)
	case "help", "-h", "--help":
		usage(os.Stdout)
	default:
		fmt.Fprintf(os.Stderr, "unknown command: %s\n\n", os.Args[1])
		usage(os.Stderr)
		os.Exit(2)
	}
}

func usage(w *os.File) {
	fmt.Fprint(w, `slap-to-yes — slap your MacBook to press Enter

Usage:
  slap-to-yes <command> [options]

Commands:
  doctor   Check hardware support and config (no sudo needed)
  run      Run the slap detector and Enter sender (sudo required)
  version  Print version
  help     Show this message

Run 'slap-to-yes <command> --help' for command-specific options.
`)
}
