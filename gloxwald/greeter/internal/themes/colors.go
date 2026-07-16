package themes

import (
	"fmt"
	"image/color"
	"os"
	"path/filepath"
	"strings"

	"github.com/BurntSushi/toml"
	"github.com/charmbracelet/lipgloss/v2"
)

// CustomThemes holds loaded custom theme configurations
var CustomThemes = make(map[string]ThemeColors)

// CustomThemeConfig represents the TOML structure for custom theme files
type CustomThemeConfig struct {
	Name   string `toml:"name"`
	Colors struct {
		BgBase      string `toml:"bg_base"`
		BgActive    string `toml:"bg_active"`
		Primary     string `toml:"primary"`
		Secondary   string `toml:"secondary"`
		Accent      string `toml:"accent"`
		Warning     string `toml:"warning"`
		Danger      string `toml:"danger"`
		FgPrimary   string `toml:"fg_primary"`
		FgSecondary string `toml:"fg_secondary"`
		FgMuted     string `toml:"fg_muted"`
		BorderFocus string `toml:"border_focus"`
	} `toml:"colors"`
}

// ThemeColors holds all colors for a theme
type ThemeColors struct {
	Name string

	BgBase    color.Color
	BgActive  color.Color
	Primary   color.Color
	Secondary color.Color
	Accent    color.Color
	Warning   color.Color
	Danger    color.Color

	FgPrimary   color.Color
	FgSecondary color.Color
	FgMuted     color.Color

	BorderDefault color.Color
	BorderFocus   color.Color
}

// ScanCustomThemes scans directories for .toml theme files and loads them
func ScanCustomThemes(dirs []string) []string {
	var names []string
	for _, dir := range dirs {
		if _, err := os.Stat(dir); os.IsNotExist(err) {
			continue // Directory doesn't exist, skip silently
		}

		files, err := filepath.Glob(filepath.Join(dir, "*.toml"))
		if err != nil {
			continue
		}

		for _, f := range files {
			theme, err := loadCustomTheme(f)
			if err != nil {
				// Silently skip invalid theme files
				continue
			}

			name := theme.Name
			if name == "" {
				name = strings.TrimSuffix(filepath.Base(f), ".toml")
			}

			if _, exists := CustomThemes[strings.ToLower(name)]; exists {
				// Theme with this name already loaded, later one wins (no error, just note)
				// This allows user themes to override system themes intentionally
			}
			CustomThemes[strings.ToLower(name)] = theme
			names = append(names, name)
		}
	}
	return names
}

// loadCustomTheme loads a single custom theme from a TOML file
func loadCustomTheme(path string) (ThemeColors, error) {
	var config CustomThemeConfig
	if _, err := toml.DecodeFile(path, &config); err != nil {
		return ThemeColors{}, err
	}

	// Validate required color fields are non-empty
	requiredFields := map[string]string{
		"bg_base":      config.Colors.BgBase,
		"bg_active":    config.Colors.BgActive,
		"primary":      config.Colors.Primary,
		"secondary":    config.Colors.Secondary,
		"accent":       config.Colors.Accent,
		"warning":      config.Colors.Warning,
		"danger":       config.Colors.Danger,
		"fg_primary":   config.Colors.FgPrimary,
		"fg_secondary": config.Colors.FgSecondary,
		"fg_muted":     config.Colors.FgMuted,
		"border_focus": config.Colors.BorderFocus,
	}

	for field, value := range requiredFields {
		if strings.TrimSpace(value) == "" {
			return ThemeColors{}, fmt.Errorf("missing required field: %s", field)
		}
	}

	name := config.Name
	if name == "" {
		name = strings.TrimSuffix(filepath.Base(path), ".toml")
	}

	return ThemeColors{
		Name:          name,
		BgBase:        lipgloss.Color(config.Colors.BgBase),
		BgActive:      lipgloss.Color(config.Colors.BgActive),
		Primary:       lipgloss.Color(config.Colors.Primary),
		Secondary:     lipgloss.Color(config.Colors.Secondary),
		Accent:        lipgloss.Color(config.Colors.Accent),
		Warning:       lipgloss.Color(config.Colors.Warning),
		Danger:        lipgloss.Color(config.Colors.Danger),
		FgPrimary:     lipgloss.Color(config.Colors.FgPrimary),
		FgSecondary:   lipgloss.Color(config.Colors.FgSecondary),
		FgMuted:       lipgloss.Color(config.Colors.FgMuted),
		BorderDefault: lipgloss.Color(config.Colors.BgActive),
		BorderFocus:   lipgloss.Color(config.Colors.BorderFocus),
	}, nil
}

// ThemeColorStrings holds hex color strings for a theme (for palette generation)
type ThemeColorStrings struct {
	BgBase    string
	BgActive  string
	Primary   string
	Secondary string
	Accent    string
	Warning   string
	Danger    string
	FgPrimary string
	FgMuted   string
}

// GetThemeColorStrings returns hex color strings for a custom theme
// Returns the colors and true if theme is custom, empty struct and false otherwise
// Used by animations package to generate theme-aware palettes
func GetThemeColorStrings(themeName string) (ThemeColorStrings, bool) {
	name := strings.ToLower(themeName)

	// Check custom themes
	if theme, ok := CustomThemes[name]; ok {
		return ThemeColorStrings{
			BgBase:    colorToHex(theme.BgBase),
			BgActive:  colorToHex(theme.BgActive),
			Primary:   colorToHex(theme.Primary),
			Secondary: colorToHex(theme.Secondary),
			Accent:    colorToHex(theme.Accent),
			Warning:   colorToHex(theme.Warning),
			Danger:    colorToHex(theme.Danger),
			FgPrimary: colorToHex(theme.FgPrimary),
			FgMuted:   colorToHex(theme.FgMuted),
		}, true
	}

	// Not a custom theme - caller should use built-in palette
	return ThemeColorStrings{}, false
}

// colorToHex converts a color.Color to hex string
// Returns #000000 if color is nil (safe fallback)
func colorToHex(c color.Color) string {
	if c == nil {
		return "#000000"
	}
	r, g, b, _ := c.RGBA()
	return fmt.Sprintf("#%02x%02x%02x", r>>8, g>>8, b>>8)
}
