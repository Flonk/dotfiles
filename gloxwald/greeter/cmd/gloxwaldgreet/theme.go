package main

import (
	"image/color"
	"strings"

	"github.com/Flonk/gloxwaldgreet/internal/themes"
)

func applyTheme(themeName string) {
	theme, ok := themes.CustomThemes[strings.ToLower(themeName)]
	if !ok {
		return
	}

	BgBase = theme.BgBase
	BgActive = theme.BgActive
	Primary = theme.Primary
	Secondary = theme.Secondary
	Accent = theme.Accent
	Warning = theme.Warning
	Danger = theme.Danger
	FgPrimary = theme.FgPrimary
	FgSecondary = theme.FgSecondary
	FgMuted = theme.FgMuted
	BorderDefault = theme.BorderDefault
	BorderFocus = theme.BorderFocus
}

func (m model) getFocusColor(target FocusState) color.Color {
	if m.focusState == target {
		return Primary
	}
	return FgSecondary
}
