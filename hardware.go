package main

import (
	"os/exec"
	"strings"
)

// cpuBrand returns e.g. "Apple M5" / "Apple M2 Pro" / "Intel Core i7-...".
// Returns ok=false if sysctl call fails (vanishingly rare).
func cpuBrand() (brand string, ok bool) {
	out, err := exec.Command("sysctl", "-n", "machdep.cpu.brand_string").Output()
	if err != nil {
		return "", false
	}
	return strings.TrimSpace(string(out)), true
}

func isAppleSilicon(brand string) bool {
	return strings.HasPrefix(brand, "Apple M")
}

// hasAccelDevice probes the IOKit registry for the AppleSPUHIDDevice that
// sits beneath the "accel" AppleSPUHIDInterface. Present on M2+ and M1 Pro;
// absent on M1 / M1 Air / Intel.
//
// Implementation note: we shell out to `ioreg -l` and substring-match. This
// is a v0.1 shortcut. A native IOKit/HID enumeration via purego is the right
// thing to do later, but ioreg is bulletproof and ships with macOS.
func hasAccelDevice() bool {
	out, err := exec.Command("ioreg", "-l").Output()
	if err != nil {
		return false
	}
	text := string(out)
	// We look for the "accel" interface specifically; "wakehint", "gyro",
	// "las" are also AppleSPUHIDInterface entries but only "accel" feeds
	// the accelerometer ring.
	if !strings.Contains(text, "+-o accel  <class AppleSPUHIDInterface") {
		return false
	}
	return strings.Contains(text, "AppleSPUHIDDevice")
}
