package main

import (
	"fmt"
	"strings"

	tea "github.com/charmbracelet/bubbletea/v2"
	"github.com/charmbracelet/lipgloss/v2"
)

const (
	fadeDelay     = 18
	wipeSpeed     = 1
	gradientSteps = 5
)

func (m model) View() tea.View {
	w, h := m.width, m.height
	if w == 0 {
		w = 80
	}
	if h == 0 {
		h = 24
	}

	content := lipgloss.JoinVertical(lipgloss.Center, m.renderASCII(), "", "", m.renderForm())

	help := "Tab Focus • F6 Shutdown • F7 Reboot • Enter Login"
	if m.loading {
		help = "Please wait..."
	}
	helpRendered := lipgloss.NewStyle().
		Foreground(lipgloss.Color(mutedHex)).
		Width(w).
		Align(lipgloss.Center).
		Render(help)

	var view tea.View
	view.Layer = lipgloss.NewCanvas(
		lipgloss.NewLayer(content).X((w-lipgloss.Width(content))/2).Y((h-lipgloss.Height(content))/2),
		lipgloss.NewLayer(helpRendered).X(0).Y(h-1),
	)
	view.BackgroundColor = lipgloss.Color(bgHex)
	return view
}

func fadeTotal(ascii string) int {
	maxDiag := 0
	for y, line := range strings.Split(ascii, "\n") {
		for x, r := range []rune(line) {
			if r != ' ' && x+y > maxDiag {
				maxDiag = x + y
			}
		}
	}
	return fadeDelay + maxDiag/wipeSpeed + gradientSteps + 1
}

func (m model) renderASCII() string {
	if m.conf.ASCII == "" {
		return ""
	}
	lines := strings.Split(m.conf.ASCII, "\n")
	width := 0
	for _, line := range lines {
		if n := len([]rune(line)); n > width {
			width = n
		}
	}
	out := make([]string, len(lines))
	for y, line := range lines {
		var b strings.Builder
		runes := []rune(line)
		for x := 0; x < width; x++ {
			if x >= len(runes) || runes[x] == ' ' {
				b.WriteRune(' ')
				continue
			}
			p := m.fadeFrame - fadeDelay - (x+y)/wipeSpeed
			var color string
			switch {
			case p < 0:
				b.WriteRune(' ')
				continue
			case p >= gradientSteps:
				color = whiteHex
			default:
				color = lerpHex(accentHex, whiteHex, float64(p)/gradientSteps)
			}
			b.WriteString(lipgloss.NewStyle().
				Foreground(lipgloss.Color(color)).
				Render(string(runes[x])))
		}
		out[y] = b.String()
	}
	return strings.Join(out, "\n")
}

func (m model) renderForm() string {
	width := min(50, m.width-12)
	if width < 26 {
		width = 26
	}

	border := lipgloss.NewStyle().
		Border(lipgloss.RoundedBorder()).
		BorderForeground(lipgloss.Color(mutedHex)).
		Padding(1, 2).
		Width(width)

	if m.loading {
		loading := lipgloss.NewStyle().
			Bold(true).
			Foreground(lipgloss.Color(accentHex)).
			Align(lipgloss.Center).
			Width(width - 6).
			Render("Authenticating... " + m.spinner.View())
		return border.Render(loading)
	}

	label := func(text string, f FocusState) string {
		color := mutedHex
		if m.focus == f {
			color = accentHex
		}
		return lipgloss.NewStyle().
			Bold(true).
			Foreground(lipgloss.Color(color)).
			Width(10).
			Render(text)
	}

	rows := []string{
		lipgloss.JoinHorizontal(lipgloss.Left, label("Username:", FocusUsername), " ", m.usernameInput.View()),
		lipgloss.JoinHorizontal(lipgloss.Left, label("Password:", FocusPassword), " ", m.passwordInput.View()),
	}

	red := lipgloss.NewStyle().Foreground(lipgloss.Color(redHex)).Bold(true)
	if m.capsLockOn && m.focus == FocusPassword {
		rows = append(rows, red.Render("⚠ CAPS LOCK ON"))
	}
	if m.errorMessage != "" {
		rows = append(rows, "", red.Render("✗ "+m.errorMessage))
	}
	if m.failedAttempts > 0 {
		rows = append(rows, "", red.Render(fmt.Sprintf("Failed attempts: %d", m.failedAttempts)))
	}

	return border.Render(lipgloss.JoinVertical(lipgloss.Left, rows...))
}
