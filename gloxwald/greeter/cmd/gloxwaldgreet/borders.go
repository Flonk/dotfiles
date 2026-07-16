package main

import (
	"image/color"

	"github.com/charmbracelet/lipgloss/v2"
)

// borders.go - All border rendering and styling functions

func (m model) renderDualBorderLayout(termWidth, termHeight int) string {
	// ===== INNER BORDER CONTENT =====
	// Contains: WM ASCII art, session dropdown, username/password fields

	// Calculate inner content area
	// Use reasonable max width like installer
	innerWidth := min(100, termWidth-8) // Reasonable width for content area
	var innerSections []string

	// WM/Session ASCII art - prominent display
	// Fix centering, art is already colored
	art := m.getSessionASCII()
	if art != "" {
		// JoinVertical(Center) handles centering, just add art
		// Art is already colored, JoinVertical(Center) will center each line
		innerSections = append(innerSections, art)
	}

	// Ensure exactly 2 lines of spacing after ASCII art
	innerSections = append(innerSections, "", "")

	// Main form (session selector, username, password) in bordered box
	// Wrap form in border for left alignment
	// Add fixed width to form content with Place
	formContentWidth := max(26, innerWidth-50)
	formContent := m.renderMainForm(formContentWidth)
	fixedFormContent := formContent
	formBorderStyle := lipgloss.NewStyle().
		Border(lipgloss.RoundedBorder()).
		BorderForeground(BorderDefault).
		Background(BgBase).
		Padding(1, 2).
		Width(formContentWidth)

	formBorder := formBorderStyle.Render(fixedFormContent)
	innerSections = append(innerSections, formBorder)

	// Title line - empty spacer to preserve centering width
	titleLine := lipgloss.NewStyle().Width(innerWidth - 6).Render("")

	// Add title as first element
	contentWithTitle := []string{titleLine}

	// Add spacing
	contentWithTitle = append(contentWithTitle, "")

	contentWithTitle = append(contentWithTitle, innerSections...)

	// Revert to Center, ASCII already has explicit centering
	innerContent := lipgloss.JoinVertical(lipgloss.Center, contentWithTitle...)

	innerBorderStyle := lipgloss.NewStyle().
		Border(m.getInnerBorderStyle()).
		BorderForeground(m.getInnerBorderColor()).
		Width(innerWidth).
		Background(BgBase).
		Padding(2, 3)

	innerBox := innerBorderStyle.Render(innerContent)

	return innerBox
}

func (m model) getInnerBorderStyle() lipgloss.Border {
	return lipgloss.Border{
		Top:    " ",
		Bottom: " ",
		Left:   " ",
		Right:  " ",
	} // Use single space border for truly minimal look
}

// Get inner border color - always static primary color
func (m model) getInnerBorderColor() color.Color {
	return Primary
}
