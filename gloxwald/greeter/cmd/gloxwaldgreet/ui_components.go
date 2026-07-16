package main

import (
	"fmt"

	"github.com/charmbracelet/lipgloss/v2"
)

// renderMainForm renders the main login form with username/password inputs
func (m model) renderMainForm(width int) string {
	var parts []string

	if m.mode == ModeLoading {
		loadingStyle := lipgloss.NewStyle().
			Bold(true).
			Foreground(Accent).
			Align(lipgloss.Center).
			Width(width)
		parts = append(parts, loadingStyle.Render("Authenticating... "+m.spinner.View()))
		return lipgloss.JoinVertical(lipgloss.Left, parts...)
	}

	// Always show both username and password fields
	labelWidth := 10
	inputStyle := lipgloss.NewStyle().
		Background(BgBase).
		Padding(0, 1)

	// Username row
	usernameLabel := lipgloss.NewStyle().
		Bold(true).
		Foreground(m.getFocusColor(FocusUsername)).
		Width(labelWidth).
		Render("Username:")
	usernameRow := lipgloss.JoinHorizontal(lipgloss.Left, usernameLabel, " ", inputStyle.Render(m.usernameInput.View()))
	parts = append(parts, usernameRow)

	// Password row
	passwordLabel := lipgloss.NewStyle().
		Bold(true).
		Foreground(m.getFocusColor(FocusPassword)).
		Width(labelWidth).
		Render("Password:")
	passwordRow := lipgloss.JoinHorizontal(lipgloss.Left, passwordLabel, " ", inputStyle.Render(m.passwordInput.View()))
	parts = append(parts, passwordRow)

	// CAPS LOCK warning
	if m.capsLockOn && m.focusState == FocusPassword {
		capsLockStyle := lipgloss.NewStyle().
			Foreground(lipgloss.Color("#FF5555")).
			Bold(true)
		parts = append(parts, capsLockStyle.Render("⚠ CAPS LOCK ON"))
	}

	// Error message
	if m.errorMessage != "" {
		errorStyle := lipgloss.NewStyle().
			Foreground(lipgloss.Color("#FF5555")).
			Bold(true)
		parts = append(parts, "")
		parts = append(parts, errorStyle.Render("✗ "+m.errorMessage))
	}

	// Failed attempt counter
	if m.failedAttempts > 0 {
		if m.failedAttempts >= 3 {
			warningStyle := lipgloss.NewStyle().
				Foreground(lipgloss.Color("#FF5555")).
				Bold(true)
			parts = append(parts, "")
			parts = append(parts, warningStyle.Render("⚠ WARNING: Multiple failed attempts may lock your account"))
		}
		attemptStyle := lipgloss.NewStyle().
			Foreground(lipgloss.Color("#FFAA00")).
			Bold(true)
		parts = append(parts, "")
		parts = append(parts, attemptStyle.Render(fmt.Sprintf("Failed attempts: %d", m.failedAttempts)))
	}

	return lipgloss.JoinVertical(lipgloss.Left, parts...)
}

// renderMainHelp renders the help text at the bottom of the screen
func (m model) renderMainHelp() string {
	switch m.mode {
	case ModeLogin, ModePassword:
		return "Tab Focus • F6 Shutdown • F7 Reboot • Enter Login"
	case ModeLoading:
		return "Please wait..."
	default:
		return ""
	}
}
