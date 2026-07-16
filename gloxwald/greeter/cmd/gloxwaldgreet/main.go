package main

import (
	"flag"
	"fmt"
	"image/color"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	"github.com/Flonk/gloxwaldgreet/internal/animations"
	"github.com/Flonk/gloxwaldgreet/internal/cache"
	"github.com/Flonk/gloxwaldgreet/internal/ipc"
	"github.com/Flonk/gloxwaldgreet/internal/themes"
	"github.com/charmbracelet/bubbles/v2/spinner"
	"github.com/charmbracelet/bubbles/v2/textinput"
	tea "github.com/charmbracelet/bubbletea/v2"
	"github.com/charmbracelet/colorprofile"
	"github.com/charmbracelet/x/ansi"
	"github.com/charmbracelet/lipgloss/v2"
)

// Version info - set via ldflags during build
var (
	Version   = "dev"
	GitCommit = "unknown"
	BuildDate = "unknown"
)

// Data directory for resources (ASCII configs, themes)
// NixOS flake injects the Nix store path at build time via ldflags
var dataDir = "/usr/share/gloxwaldgreet"

var debugLog *log.Logger

func initDebugLog() {
	// Try persistent location first ($HOME/.cache/gloxwaldgreet/debug.log)
	// Falls back to /tmp/ if home dir unavailable
	logPath := "/tmp/gloxwaldgreet-debug.log"
	if home, err := os.UserHomeDir(); err == nil {
		cacheDir := filepath.Join(home, ".cache", "gloxwaldgreet")
		os.MkdirAll(cacheDir, 0755)
		logPath = filepath.Join(cacheDir, "debug.log")
	}

	logFile, err := os.OpenFile(logPath, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0644)
	if err != nil {
		// Fallback to stderr if can't open log file
		debugLog = log.New(os.Stderr, "[DEBUG] ", log.Ldate|log.Ltime|log.Lshortfile)
		return
	}
	debugLog = log.New(logFile, "[DEBUG] ", log.Ldate|log.Ltime|log.Lshortfile)
}

func logDebug(format string, args ...interface{}) {
	if debugLog != nil {
		debugLog.Printf(format, args...)
	}
}

// TTY-safe colors with profile detection
var (
	// Detect color profile once at startup
	colorProfile = colorprofile.Detect(os.Stdout, os.Environ())
	complete     = lipgloss.Complete(colorProfile)

	// Backgrounds - using Complete() for TTY compatibility
	BgBase   color.Color
	BgActive color.Color

	// Primary brand colors
	Primary   color.Color
	Secondary color.Color
	Accent    color.Color
	Warning   color.Color
	Danger    color.Color

	// Text colors
	FgPrimary   color.Color
	FgSecondary color.Color
	FgMuted     color.Color

	// Border colors
	BorderDefault color.Color
	BorderFocus   color.Color
)

func init() {
	// Initialize colors with TTY fallbacks
	// Dark background - fallback to black on TTY
	BgBase = complete(
		lipgloss.Color("0"),       // ANSI black
		lipgloss.Color("235"),     // ANSI256 dark gray
		lipgloss.Color("#1a1a1a"), // TrueColor charcoal
	)
	BgActive = BgBase

	// Primary violet - fallback to magenta on TTY
	Primary = complete(
		lipgloss.Color("5"),       // ANSI magenta
		lipgloss.Color("141"),     // ANSI256 purple
		lipgloss.Color("#8b5cf6"), // TrueColor violet
	)

	// Secondary cyan
	Secondary = complete(
		lipgloss.Color("6"),       // ANSI cyan
		lipgloss.Color("45"),      // ANSI256 cyan
		lipgloss.Color("#06b6d4"), // TrueColor cyan
	)

	// Accent green
	Accent = complete(
		lipgloss.Color("2"),       // ANSI green
		lipgloss.Color("42"),      // ANSI256 green
		lipgloss.Color("#10b981"), // TrueColor emerald
	)

	// Warning amber
	Warning = complete(
		lipgloss.Color("3"),       // ANSI yellow
		lipgloss.Color("214"),     // ANSI256 orange
		lipgloss.Color("#f59e0b"), // TrueColor amber
	)

	// Danger red
	Danger = complete(
		lipgloss.Color("1"),       // ANSI red
		lipgloss.Color("196"),     // ANSI256 red
		lipgloss.Color("#ef4444"), // TrueColor red
	)

	// Primary text - white
	FgPrimary = complete(
		lipgloss.Color("7"),       // ANSI white
		lipgloss.Color("255"),     // ANSI256 white
		lipgloss.Color("#f8fafc"), // TrueColor white
	)

	// Secondary text - light gray
	FgSecondary = complete(
		lipgloss.Color("7"),       // ANSI white
		lipgloss.Color("252"),     // ANSI256 light gray
		lipgloss.Color("#cbd5e1"), // TrueColor light gray
	)

	// Muted text - gray
	FgMuted = complete(
		lipgloss.Color("8"),       // ANSI bright black
		lipgloss.Color("244"),     // ANSI256 gray
		lipgloss.Color("#94a3b8"), // TrueColor gray
	)

	// Border default - dark gray
	BorderDefault = complete(
		lipgloss.Color("8"),       // ANSI bright black
		lipgloss.Color("238"),     // ANSI256 dark gray
		lipgloss.Color("#374151"), // TrueColor gray
	)

	BorderFocus = Primary
}


type ASCIIConfig struct {
	Name          string
	ASCIIVariants []string
	Color         string // Optional hex color override (e.g., "#89b4fa")
	Effect        string // "beams" or "" (none)
	Exec          string // Fixed launch command (e.g., "start-hyprland"); skips session selection
}

type Config struct {
	TestMode         bool
	Debug            bool
	ShowTime         bool
	ThemeName        string
	RememberUsername bool
}

type ViewMode string

const (
	ModeLogin    ViewMode = "login"
	ModePassword ViewMode = "password"
	ModeLoading  ViewMode = "loading"
)

type FocusState int

const (
	FocusUsername FocusState = iota
	FocusPassword
)

type model struct {
	usernameInput textinput.Model
	passwordInput textinput.Model
	spinner       spinner.Model
	execCmd       string // Fixed exec command from ASCII config
	ipcClient     *ipc.Client
	mode          ViewMode
	config        Config

	// Terminal dimensions
	width  int
	height int


	currentTheme string

	// Focus management
	focusState FocusState

	// Authentication tracking
	failedAttempts int

	errorMessage string

	capsLockOn    bool // CAPS LOCK state detected via kitty keyboard protocol
	kittyUpgraded bool // Whether we've upgraded kitty keyboard flags for non-US layout support

	// ASCII Effects
	beamsEffect *animations.BeamsTextEffect // Beams text effect for ASCII art
}

type tickMsg time.Time

func doTick() tea.Cmd {
	return tea.Tick(time.Millisecond*30, func(t time.Time) tea.Msg {
		return tickMsg(t)
	})
}

func initialModel(config Config) model {
	// Setup username input with proper styling
	ti := textinput.New()
	ti.Prompt = ""      // Remove prompt, will be added by layout
	ti.Placeholder = "" // Remove placeholder
	// Updated for textinput v2 API
	ti.Styles.Focused.Prompt = lipgloss.NewStyle().Foreground(Primary).Bold(true)
	ti.Styles.Focused.Text = lipgloss.NewStyle().Foreground(FgPrimary)
	ti.Styles.Focused.Placeholder = lipgloss.NewStyle().Foreground(FgMuted).Italic(true)

	// Setup password input
	pi := textinput.New()
	pi.Prompt = ""      // Remove prompt, will be added by layout
	pi.Placeholder = "" // Remove placeholder
	pi.EchoMode = textinput.EchoPassword
	// Updated for textinput v2 API
	pi.Styles.Focused.Prompt = lipgloss.NewStyle().Foreground(Primary).Bold(true)
	pi.Styles.Focused.Text = lipgloss.NewStyle().Foreground(FgPrimary)
	pi.Styles.Focused.Placeholder = lipgloss.NewStyle().Foreground(FgMuted).Italic(true)

	// Load greeter config (ASCII art, effect, exec command)
	greeterConfigPath := fmt.Sprintf("%s/ascii_configs/hyprland.conf", dataDir)
	greeterConfig, _ := loadASCIIConfig(greeterConfigPath)

	execCmd := greeterConfig.Exec
	if config.TestMode && execCmd == "" {
		execCmd = "Hyprland"
	}
	if config.Debug {
		logDebug("Exec command: %s", execCmd)
	}

	// Setup animated spinner
	sp := spinner.New()
	sp.Spinner = spinner.Points
	sp.Style = lipgloss.NewStyle().Foreground(Primary)

	var ipcClient *ipc.Client

	if !config.TestMode {
		logDebug("Attempting to create IPC client...")
		client, err := ipc.NewClient()
		if err != nil {
			// CRITICAL: If IPC fails, we cannot authenticate with greetd
			// Log the error and exit rather than continue with nil client
			logDebug("FATAL: IPC client creation failed: %v", err)
			fmt.Fprintf(os.Stderr, "FATAL: Failed to create IPC client: %v\n", err)
			fmt.Fprintf(os.Stderr, "GREETD_SOCK environment variable: %s\n", os.Getenv("GREETD_SOCK"))
			fmt.Fprintf(os.Stderr, "This greeter must be run by greetd with GREETD_SOCK set.\n")
			os.Exit(1)
		}
		ipcClient = client
		logDebug("IPC client created successfully")
	}

	// Scan and load custom themes from config directories
	themeDirs := []string{
		dataDir + "/themes",
		filepath.Join(os.Getenv("HOME"), ".config/gloxwaldgreet/themes"),
	}
	themes.ScanCustomThemes(themeDirs)

	// Apply theme: CLI flag > first available custom theme > hardcoded defaults
	initialTheme := ""
	if config.ThemeName != "" {
		initialTheme = config.ThemeName
	} else {
		// Use first available custom theme
		for name := range themes.CustomThemes {
			initialTheme = name
			break
		}
	}
	if initialTheme != "" {
		applyTheme(initialTheme)
	}

	// Set initial focus
	ti.Focus()

	m := model{
		usernameInput: ti,
		passwordInput: pi,
		spinner:       sp,
		execCmd:       execCmd,
		ipcClient:     ipcClient,
		mode:          ModeLogin,
		config:        config,
		width:         80,
		height:        24,
		focusState:    FocusUsername,
		currentTheme:  initialTheme,
	}

	// Initialize beams effect if ASCII config requests it
	if len(greeterConfig.ASCIIVariants) > 0 && greeterConfig.Effect == "beams" {
		ascii := greeterConfig.ASCIIVariants[0]
		beamColors, finalColors := getThemeColorsForBeams(m.currentTheme)
		lines := strings.Split(ascii, "\n")
		asciiHeight := len(lines)
		asciiWidth := 0
		for _, line := range lines {
			if len([]rune(line)) > asciiWidth {
				asciiWidth = len([]rune(line))
			}
		}
		m.beamsEffect = animations.NewBeamsTextEffect(animations.BeamsTextConfig{
			Width:              asciiWidth,
			Height:             asciiHeight,
			Text:               ascii,
			BeamGradientStops:  beamColors,
			FinalGradientStops: finalColors,
		})
	}

	// Load cached preferences (username)
	if !m.config.TestMode {
		if prefs, err := cache.LoadPreferences(); err == nil && prefs != nil {
			// Auto-advance to password if username is cached
			if m.config.RememberUsername && prefs.Username != "" {
				m.usernameInput.SetValue(prefs.Username)
				m.mode = ModePassword
				m.focusState = FocusPassword
				m.usernameInput.Blur()
				m.passwordInput.Focus()
				logDebug("Loaded cached username '%s' - auto-advancing to password", prefs.Username)
			}
		}
	}

	return m
}

func (m model) Init() tea.Cmd {
	// Request keyboard enhancements to get CAPS LOCK state reporting
	// RequestUniformKeyLayout enables kitty flags 4+8 which includes lock key state reporting
	return tea.Batch(
		textinput.Blink,
		m.spinner.Tick,
		doTick(),
		tea.RequestUniformKeyLayout,
	)
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	var cmds []tea.Cmd

	switch msg := msg.(type) {
	case tea.KeyboardEnhancementsMsg:
		// Upgrade kitty keyboard protocol to include alternate key and associated text reporting.
		// Without these flags, non-US keyboard layouts (e.g., German QWERTZ) get wrong characters
		// for shifted keys because kitty sends the base keycode without layout-aware text.
		// Mode 2 = add flags without removing existing ones (preserves CapsLock detection).
		if !m.kittyUpgraded {
			m.kittyUpgraded = true
			flags := ansi.KittyReportAlternateKeys | ansi.KittyReportAssociatedKeys
			logDebug("Upgrading kitty keyboard flags: adding %d (ReportAlternateKeys|ReportAssociatedKeys)", flags)
			return m, tea.Raw(ansi.KittyKeyboard(flags, 2))
		}

	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height
		logDebug("Terminal resized: %dx%d", msg.Width, msg.Height)
		return m, nil

	case tickMsg:
		if m.beamsEffect != nil {
			m.beamsEffect.Update()
		}

		cmds = append(cmds, doTick())


	case string:
		if msg == "success" {
			// Removed delay workaround
			// Now we properly wait for greetd's success response in StartSession() before returning
			// This ensures greetd has finished session initialization regardless of hardware speed

			m.failedAttempts = 0 // Reset failed attempts on successful login

			if !m.config.TestMode {
				username := ""
				if m.config.RememberUsername {
					username = m.usernameInput.Value()
				}
				cache.SavePreferences(cache.UserPreferences{
					Username: username,
				})
				logDebug("Saved username '%s'", username)
			}

			fmt.Println("Session started successfully")
			return m, tea.Quit
		} else {
			m.errorMessage = msg
			m.mode = ModeLogin
			m.usernameInput.SetValue("") // Clear username field
			m.passwordInput.SetValue("") // Clear password field
			m.usernameInput.Focus()
			m.passwordInput.Blur()
			m.focusState = FocusUsername
			return m, textinput.Blink
		}
	case error:
		m.errorMessage = msg.Error()
		m.failedAttempts++ // Track failed authentication attempts
		m.mode = ModePassword
		// Keep username, only clear password
		m.passwordInput.SetValue("")
		m.passwordInput.Focus()
		m.usernameInput.Blur()
		m.focusState = FocusPassword
		return m, textinput.Blink

	case tea.KeyMsg:
		// Kitty keyboard protocol sends CAPS LOCK and NUM LOCK as ModCapsLock and ModNumLock
		key := msg.Key()
		m.capsLockOn = (key.Mod & tea.ModCapsLock) != 0

		if m.config.Debug {
			// Log ALL key presses to debug what modifiers are being sent
			fmt.Fprintf(os.Stderr, "KEY: %q | Mod=%08b (%d) | CapsLock=%v\n",
				key.Text, key.Mod, key.Mod, m.capsLockOn)
		}

		newModel, cmd := m.handleKeyInput(msg)
		m = newModel
		cmds = append(cmds, cmd)

	case tea.MouseMsg:
		// Mouse input handled
	}

	// Update components based on current mode and focus
	switch m.mode {
	case ModeLogin:
		if m.focusState == FocusUsername {
			var cmd tea.Cmd
			m.usernameInput, cmd = m.usernameInput.Update(msg)
			cmds = append(cmds, cmd)
			if m.errorMessage != "" && len(m.usernameInput.Value()) > 0 {
				m.errorMessage = ""
			}
		}
	case ModePassword:
		if m.focusState == FocusPassword {
			var cmd tea.Cmd
			m.passwordInput, cmd = m.passwordInput.Update(msg)
			cmds = append(cmds, cmd)
			if m.errorMessage != "" && len(m.passwordInput.Value()) > 0 {
				m.errorMessage = ""
			}
		}
	case ModeLoading:
		var cmd tea.Cmd
		m.spinner, cmd = m.spinner.Update(msg)
		cmds = append(cmds, cmd)
	}

	return m, tea.Batch(cmds...)
}

func (m model) handleKeyInput(msg tea.KeyMsg) (model, tea.Cmd) {
	// Updated for tea.KeyMsg v2 API
	if m.config.Debug {
		keyStr := msg.String()
		fmt.Fprintf(os.Stderr, "KEY DEBUG: String='%s'\n", keyStr)
	}

	switch msg.String() {
	case "ctrl+c", "q":
		// Only allow Ctrl+C/Q to quit in test mode (when ipcClient is nil)
		if m.ipcClient == nil {
			// Test mode - allow quit
			return m, tea.Quit
		}
		// Production mode - ignore Ctrl+C/Q (security measure)
		return m, nil

	case "f6":
		if m.config.TestMode {
			fmt.Println("Test mode: Would shutdown system")
			return m, tea.Quit
		}
		// Stay alive: systemd 260+ kills all processes in session scope on greeter exit
		exec.Command("systemctl", "poweroff").Start()
		m.mode = ModeLoading
		return m, nil

	case "f7":
		if m.config.TestMode {
			fmt.Println("Test mode: Would reboot system")
			return m, tea.Quit
		}
		exec.Command("systemctl", "reboot").Start()
		m.mode = ModeLoading
		return m, nil

	case "tab":
		// Cycle focus: Username -> Password -> Username
		switch m.focusState {
		case FocusUsername:
			m.mode = ModePassword
			m.focusState = FocusPassword
			m.usernameInput.Blur()
			m.passwordInput.Focus()
		case FocusPassword:
			m.mode = ModeLogin
			m.focusState = FocusUsername
			m.passwordInput.Blur()
			m.usernameInput.Focus()
		}
		return m, textinput.Blink

	case "shift+tab":
		// Reverse cycle: Password -> Username -> Password
		switch m.focusState {
		case FocusUsername:
			m.mode = ModePassword
			m.focusState = FocusPassword
			m.usernameInput.Blur()
			m.passwordInput.Focus()
		case FocusPassword:
			m.mode = ModeLogin
			m.focusState = FocusUsername
			m.passwordInput.Blur()
			m.usernameInput.Focus()
		}
		return m, textinput.Blink

	case "esc":
		switch m.mode {
		case ModePassword:
			m.mode = ModeLogin
			m.focusState = FocusUsername
			m.passwordInput.SetValue("") // Clear password field
			m.usernameInput.Focus()
			m.passwordInput.Blur()
			return m, textinput.Blink
		}


	case "enter":
		switch m.mode {
		case ModeLogin:
			// Enter from username goes to password
			if m.config.Debug {
				fmt.Println("Debug: Switching to password mode")
			}
			m.mode = ModePassword
			m.focusState = FocusPassword
			m.usernameInput.Blur()
			m.passwordInput.Focus()
			return m, textinput.Blink

		case ModePassword:
			// Enter from password submits
			username := m.usernameInput.Value()
			password := m.passwordInput.Value()
			if m.config.Debug {
				// SECURITY: Never log passwords - only log username for debugging
				logDebug(" Authentication attempt for user: %s", username)
			}
			if m.config.TestMode {
				fmt.Println("Test mode: Auth successful")
				return m, tea.Quit
			} else {
				if m.ipcClient == nil {
					fmt.Println("Error: No IPC client available")
					return m, tea.Quit
				}
				m.mode = ModeLoading
				return m, m.authenticate(username, password)
			}

		}
	}

	return m, nil
}

// Return tea.View with BackgroundColor set
func (m model) View() tea.View {
	// Use full terminal dimensions
	termWidth := m.width
	termHeight := m.height
	if termWidth == 0 {
		termWidth = 80
	}
	if termHeight == 0 {
		termHeight = 24
	}

	content := m.renderMainView(termWidth, termHeight)

	var view tea.View

	// Center main content
	contentWidth := lipgloss.Width(content)
	contentHeight := lipgloss.Height(content)
	x := (termWidth - contentWidth) / 2
	y := (termHeight - contentHeight) / 2

	// Help text pinned to the bottom of the screen
	helpText := m.renderMainHelp()
	helpStyle := lipgloss.NewStyle().
		Foreground(FgMuted).
		Width(termWidth).
		Align(lipgloss.Center)
	helpRendered := helpStyle.Render(helpText)
	helpY := termHeight - 1

	view.Layer = lipgloss.NewCanvas(
		lipgloss.NewLayer(content).X(x).Y(y),
		lipgloss.NewLayer(helpRendered).X(0).Y(helpY),
	)
	view.BackgroundColor = BgBase
	return view
}


// Complete dual border redesign
func (m model) renderMainView(termWidth, termHeight int) string {
	return m.renderDualBorderLayout(termWidth, termHeight)
}

func (m model) authenticate(username, password string) tea.Cmd {
	return func() tea.Msg {
		if m.ipcClient == nil {
			return fmt.Errorf("IPC client not initialized - greeter must be run by greetd")
		}

		// Create session
		if err := m.ipcClient.CreateSession(username); err != nil {
			return err
		}
		// Receive auth message
		resp, err := m.ipcClient.ReceiveResponse()
		if err != nil {
			// Cancel session on error
			m.ipcClient.CancelSession()
			return err
		}

		if errResp, ok := resp.(ipc.Error); ok {
			// Cancel session on error
			m.ipcClient.CancelSession()
			return fmt.Errorf("authentication failed: %s - %s", errResp.ErrorType, errResp.Description)
		}

		if _, ok := resp.(ipc.AuthMessage); ok {
			if m.config.Debug {
				logDebug(" Received auth message")
			}
			// Send password as response
			// FIXED: Pass password as value instead of pointer to avoid capture issues
			passwordCopy := password
			if err := m.ipcClient.PostAuthMessageResponse(&passwordCopy); err != nil {
				// Cancel session on error
				m.ipcClient.CancelSession()
				return err
			}
			// Receive success or error
			resp, err := m.ipcClient.ReceiveResponse()
			if err != nil {
				// Cancel session on error
				m.ipcClient.CancelSession()
				return err
			}

			if errResp, ok := resp.(ipc.Error); ok {
				// Cancel session on authentication failure
				m.ipcClient.CancelSession()
				return fmt.Errorf("authentication failed: %s - %s", errResp.ErrorType, errResp.Description)
			}

			if _, ok := resp.(ipc.Success); ok {
				// Start session
				// Add --unsupported-gpu flag for Sway sessions (NVIDIA compatibility)
				execParts := strings.Fields(m.execCmd)
				if len(execParts) > 0 && filepath.Base(execParts[0]) == "sway" {
					// Check if --unsupported-gpu is already present (avoid duplicates)
					hasFlag := false
					for _, part := range execParts {
						if part == "--unsupported-gpu" {
							hasFlag = true
							break
						}
					}
					if !hasFlag {
						// Insert --unsupported-gpu after the binary name but before other args
						execParts = append([]string{execParts[0], "--unsupported-gpu"}, execParts[1:]...)
					}
				}
				// Use parsed Exec (with --unsupported-gpu added if needed)
				cmd := execParts
				env := []string{} // Can be populated if needed
				if err := m.ipcClient.StartSession(cmd, env); err != nil {
					// Cancel session on StartSession failure
					m.ipcClient.CancelSession()
					return err
				}
				return "success"
			} else {
				// Cancel session on unexpected response
				m.ipcClient.CancelSession()
				return fmt.Errorf("expected success or error, got %T", resp)
			}
		} else {
			// Cancel session on unexpected response
			m.ipcClient.CancelSession()
			return fmt.Errorf("expected auth message or error, got %T", resp)
		}
	}
}

func main() {
	// Initialize config with defaults
	config := Config{
		RememberUsername: true, // Default: remember username
	}

	var showVersion bool

	flag.BoolVar(&showVersion, "version", false, "Show version information")
	flag.BoolVar(&showVersion, "v", false, "Show version information (shorthand)")
	flag.BoolVar(&config.TestMode, "test", false, "Enable test mode (no actual authentication)")
	flag.BoolVar(&config.Debug, "debug", false, "Enable debug output")
	flag.StringVar(&config.ThemeName, "theme", "", "Custom theme name (from .toml files in themes directory)")
	flag.StringVar(&dataDir, "data-dir", dataDir, "Path to data directory (ascii_configs, themes)")
	flag.BoolVar(&config.RememberUsername, "remember-username", true, "Remember last logged in username")
	flag.BoolVar(&config.ShowTime, "time", false, "") // Hidden flag - not shown in help

	// Add help text
	flag.Usage = func() {
		fmt.Fprintf(os.Stderr, "Usage: %s [OPTIONS]\n\n", os.Args[0])
		fmt.Fprintf(os.Stderr, "gloxwaldgreet - A terminal greeter for greetd\n\n")
		fmt.Fprintf(os.Stderr, "Options:\n")
		// Manually print flags (excluding hidden ones)
		fmt.Fprintf(os.Stderr, "  -debug\n")
		fmt.Fprintf(os.Stderr, "    	Enable debug output\n")
		fmt.Fprintf(os.Stderr, "  -test\n")
		fmt.Fprintf(os.Stderr, "    	Enable test mode (no actual authentication)\n")
		fmt.Fprintf(os.Stderr, "  -theme string\n")
		fmt.Fprintf(os.Stderr, "    	Custom theme name (from .toml files in themes directory)\n")
		fmt.Fprintf(os.Stderr, "  -v	Show version information (shorthand)\n")
		fmt.Fprintf(os.Stderr, "  -version\n")
		fmt.Fprintf(os.Stderr, "    	Show version information\n")
		fmt.Fprintf(os.Stderr, "\nConfiguration:\n")
		fmt.Fprintf(os.Stderr, "  ASCII configs: %s/ascii_configs/\n", dataDir)
		fmt.Fprintf(os.Stderr, "\nKey Bindings:\n")
		fmt.Fprintf(os.Stderr, "  Tab       Cycle focus between Username and Password\n")
		fmt.Fprintf(os.Stderr, "  F6        Shutdown\n")
		fmt.Fprintf(os.Stderr, "  F7        Reboot\n")
		fmt.Fprintf(os.Stderr, "  Enter     Continue to next step\n")
		fmt.Fprintf(os.Stderr, "  Esc       Cancel/go back\n")
		fmt.Fprintf(os.Stderr, "  Ctrl+C    Quit\n")
	}

	flag.Parse()

	// Handle version flag
	if showVersion {
		fmt.Printf("gloxwaldgreet %s\n", Version)
		fmt.Printf("Commit: %s\n", GitCommit)
		fmt.Printf("Built: %s\n", BuildDate)
		os.Exit(0)
	}

	// SECURITY: Prevent test mode in production environment
	// Test mode bypasses authentication and should only be used for development
	if config.TestMode && os.Getenv("GREETD_SOCK") != "" {
		fmt.Fprintf(os.Stderr, "SECURITY ERROR: Test mode cannot be enabled in production (GREETD_SOCK is set)\n")
		fmt.Fprintf(os.Stderr, "Test mode bypasses authentication and should only be used for development.\n")
		os.Exit(1)
	}

	initDebugLog()
	logDebug("=== gloxwaldgreet started ===")
	logDebug("Version: gloxwaldgreet greeter")
	logDebug("Test mode: %v", config.TestMode)
	logDebug("Debug mode: %v", config.Debug)
	logDebug("Theme: %s", config.ThemeName)
	logDebug("GREETD_SOCK: %s", os.Getenv("GREETD_SOCK"))
	logDebug("WAYLAND_DISPLAY: %s", os.Getenv("WAYLAND_DISPLAY"))
	logDebug("XDG_RUNTIME_DIR: %s", os.Getenv("XDG_RUNTIME_DIR"))

	if config.Debug {
		fmt.Printf("Debug mode enabled\n")
		fmt.Printf("Debug log: /tmp/gloxwaldgreet-debug.log\n")
	}

	// Initialize Bubble Tea program with proper screen management
	opts := []tea.ProgramOption{}

	// Check if we can access TTY before using alt screen
	if _, err := os.OpenFile("/dev/tty", os.O_RDWR, 0); err != nil {
		// No TTY access - use basic program options
		if config.Debug {
			logDebug(" No TTY access, running without alt screen")
		}
	} else {
		// TTY available - use full screen features
		opts = append(opts, tea.WithAltScreen())
		if !config.TestMode {
			opts = append(opts, tea.WithMouseCellMotion())
		}
	}

	p := tea.NewProgram(initialModel(config), opts...)

	if _, err := p.Run(); err != nil {
		fmt.Printf("Error: %v\n", err)
		os.Exit(1)
	}
}
