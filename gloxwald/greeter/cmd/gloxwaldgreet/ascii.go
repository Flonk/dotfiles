package main

import (
	"fmt"
	"os"
	"strings"

	"github.com/Flonk/gloxwaldgreet/internal/animations"
	"github.com/charmbracelet/lipgloss/v2"
)

// ascii.go - ASCII art configuration, loading, rendering, and animations

func loadASCIIConfig(configPath string) (ASCIIConfig, error) {
	var config ASCIIConfig

	data, err := os.ReadFile(configPath)
	if err != nil {
		return config, err
	}

	content := string(data)
	lines := strings.Split(content, "\n")

	var currentVariantLines []string
	inASCII := false

	for _, line := range lines {
		trimmedLine := strings.TrimSpace(line)

		// Skip comments and empty lines
		if strings.HasPrefix(trimmedLine, "#") || trimmedLine == "" {
			continue
		}

		if strings.Contains(trimmedLine, "=") {
			parts := strings.SplitN(trimmedLine, "=", 2)
			key := strings.TrimSpace(parts[0])
			value := strings.TrimSpace(parts[1])

			// Check if this is a new ASCII variant (ascii_1, ascii_2, etc.)
			if strings.HasPrefix(key, "ascii_") || key == "ascii" {
				// Save previous variant if exists
				if inASCII && len(currentVariantLines) > 0 {
					variant := strings.Join(currentVariantLines, "\n")
					// Trim trailing newlines for height consistency
					variant = strings.TrimRight(variant, "\n")
					config.ASCIIVariants = append(config.ASCIIVariants, variant)
				}

				// Start new variant
				currentVariantLines = []string{}
				inASCII = true

				if value != "" && value != `"""` {
					currentVariantLines = append(currentVariantLines, value)
				}
			} else {
				// Save any pending ASCII variant before switching to other keys
				if inASCII && len(currentVariantLines) > 0 {
					variant := strings.Join(currentVariantLines, "\n")
					variant = strings.TrimRight(variant, "\n")
					config.ASCIIVariants = append(config.ASCIIVariants, variant)

					currentVariantLines = []string{}
					inASCII = false
				}

				// Handle other config keys
				switch key {
				case "name":
					config.Name = value
				case "color":
					config.Color = strings.TrimSpace(value)
				case "effect":
					config.Effect = strings.TrimSpace(value)
				case "exec":
					config.Exec = strings.TrimSpace(value)
				case "animation_style", "animation_speed", "animation_direction", "roasts":
					// Ignored legacy keys
				}
			}
		} else if inASCII {
			if trimmedLine == `"""` {
				// End ASCII section and save variant
				if len(currentVariantLines) > 0 {
					variant := strings.Join(currentVariantLines, "\n")
					variant = strings.TrimRight(variant, "\n")
					config.ASCIIVariants = append(config.ASCIIVariants, variant)
				}
				currentVariantLines = []string{}
				inASCII = false
				continue
			}
			currentVariantLines = append(currentVariantLines, line)
		}
	}

	// Save final variant if exists
	if inASCII && len(currentVariantLines) > 0 {
		variant := strings.Join(currentVariantLines, "\n")
		variant = strings.TrimRight(variant, "\n")
		config.ASCIIVariants = append(config.ASCIIVariants, variant)
	}

	return config, nil
}

// getSessionASCII loads and renders ASCII art from the single config file
func (m model) getSessionASCII() string {
	configPath := fmt.Sprintf("%s/ascii_configs/hyprland.conf", dataDir)
	asciiConfig, err := loadASCIIConfig(configPath)
	if err != nil {
		return ""
	}

	if len(asciiConfig.ASCIIVariants) == 0 {
		return ""
	}

	currentASCII := asciiConfig.ASCIIVariants[0]

	if m.beamsEffect != nil {
		return m.beamsEffect.Render()
	}

	// Determine ASCII color: use config override if set, otherwise theme Primary
	asciiColor := Primary
	if asciiConfig.Color != "" {
		asciiColor = lipgloss.Color(asciiConfig.Color)
	}

	// Apply color to entire ASCII art block
	style := lipgloss.NewStyle().Foreground(asciiColor).Background(BgBase)
	return style.Render(currentASCII)
}

// resetBeamsEffect reinitializes beams effect from the single ASCII config
func (m *model) resetBeamsEffect() {
	if m.beamsEffect == nil {
		return
	}

	configPath := fmt.Sprintf("%s/ascii_configs/hyprland.conf", dataDir)
	if asciiConfig, err := loadASCIIConfig(configPath); err == nil && len(asciiConfig.ASCIIVariants) > 0 {
		ascii := asciiConfig.ASCIIVariants[0]

		// Recalculate dimensions for the ASCII
		lines := strings.Split(ascii, "\n")
		asciiHeight := len(lines)
		asciiWidth := 0
		for _, line := range lines {
			if len([]rune(line)) > asciiWidth {
				asciiWidth = len([]rune(line))
			}
		}

		// Get current theme colors
		beamColors, finalColors := getThemeColorsForBeams(m.currentTheme)

		// Reinitialize beams effect completely with new dimensions and colors
		m.beamsEffect = animations.NewBeamsTextEffect(animations.BeamsTextConfig{
			Width:              asciiWidth,
			Height:             asciiHeight,
			Text:               ascii,
			BeamGradientStops:  beamColors,
			FinalGradientStops: finalColors,
		})
	}
}
