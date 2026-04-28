package main

import (
	"os/exec"
	"strings"
)

// frontmostBundleID returns the bundle ID of the foreground app, or "" if
// it can't be determined. v0.1 shells out to osascript; native CGO/purego
// via NSWorkspace is a v0.2 optimization (~50ms saved per call).
func frontmostBundleID() string {
	out, err := exec.Command("osascript", "-e",
		`tell application "System Events" to get bundle identifier of (first process whose frontmost is true)`).Output()
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(out))
}

// sendEnter posts a synthetic Return key press to the frontmost window.
// Requires "Accessibility" permission for whichever process is running
// the binary; macOS will prompt the first time.
//
// AppleScript key code 36 = kVK_Return.
func sendEnter() error {
	return exec.Command("osascript", "-e",
		`tell application "System Events" to key code 36`).Run()
}

func contains(list []string, s string) bool {
	if s == "" {
		return false
	}
	for _, x := range list {
		if x == s {
			return true
		}
	}
	return false
}
