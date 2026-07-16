package main

import (
	"fmt"
	"strings"
)

var (
	bgHex     = "#1a1a1a"
	fgHex     = "#f8fafc"
	accentHex = "#ff9529"
)

const (
	whiteHex = "#ffffff"
	mutedHex = "#677383"
	redHex   = "#ff5555"
)

func applyColors(bg, fg, accent string) {
	if bg != "" {
		bgHex = bg
	}
	if fg != "" {
		fgHex = fg
	}
	if accent != "" {
		accentHex = accent
	}
}

func lerpHex(a, b string, t float64) string {
	pa, pb := parseHex(a), parseHex(b)
	var out [3]uint8
	for i := range out {
		out[i] = uint8(float64(pa[i])*(1-t) + float64(pb[i])*t)
	}
	return fmt.Sprintf("#%02x%02x%02x", out[0], out[1], out[2])
}

func parseHex(hex string) [3]uint8 {
	hex = strings.TrimPrefix(hex, "#")
	if len(hex) != 6 {
		return [3]uint8{255, 255, 255}
	}
	var r, g, b uint8
	fmt.Sscanf(hex, "%02x%02x%02x", &r, &g, &b)
	return [3]uint8{r, g, b}
}
