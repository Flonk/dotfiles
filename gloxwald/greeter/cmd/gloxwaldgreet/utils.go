package main

import (
	"github.com/Flonk/gloxwaldgreet/internal/themes"
)

// min returns the minimum of two integers
func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}

// getThemeColorsForBeams returns color palette for beams effect based on theme
func getThemeColorsForBeams(themeName string) ([]string, []string) {
	// Check custom themes
	if colors, ok := themes.GetThemeColorStrings(themeName); ok {
		return []string{colors.FgPrimary, colors.Secondary, colors.Primary},
			[]string{colors.FgMuted, colors.Primary, colors.FgPrimary}
	}

	// Default fallback
	return []string{"#ffffff", "#00D1FF", "#8A008A"},
		[]string{"#4A4A4A", "#00D1FF", "#FFFFFF"}
}
