package main

import (
	"flag"
	"fmt"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	"github.com/Flonk/gloxwaldgreet/internal/ipc"
	"github.com/charmbracelet/bubbles/v2/spinner"
	"github.com/charmbracelet/bubbles/v2/textinput"
	tea "github.com/charmbracelet/bubbletea/v2"
	"github.com/charmbracelet/lipgloss/v2"
	"github.com/charmbracelet/x/ansi"
)

var (
	Version   = "dev"
	GitCommit = "unknown"
	BuildDate = "unknown"
)

var defaultAsciiPath = "/usr/share/gloxwaldgreet/ascii.txt"

var debugLog *log.Logger

func initDebugLog() {
	logPath := "/tmp/gloxwaldgreet-debug.log"
	if home, err := os.UserHomeDir(); err == nil {
		dir := filepath.Join(home, ".cache", "gloxwaldgreet")
		os.MkdirAll(dir, 0755)
		logPath = filepath.Join(dir, "debug.log")
	}
	f, err := os.OpenFile(logPath, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0644)
	if err != nil {
		debugLog = log.New(os.Stderr, "[DEBUG] ", log.Ldate|log.Ltime)
		return
	}
	debugLog = log.New(f, "[DEBUG] ", log.Ldate|log.Ltime)
}

func logDebug(format string, args ...interface{}) {
	if debugLog != nil {
		debugLog.Printf(format, args...)
	}
}

type Config struct {
	Exec  string
	User  string
	ASCII string
}

type FocusState int

const (
	FocusUsername FocusState = iota
	FocusPassword
)

type model struct {
	usernameInput textinput.Model
	passwordInput textinput.Model
	spinner       spinner.Model
	conf          Config
	ipcClient     *ipc.Client
	testMode      bool

	width          int
	height         int
	loading        bool
	focus          FocusState
	failedAttempts int
	errorMessage   string
	fadeFrame      int
	fadeEnd        int
	capsLockOn     bool
	kittyUpgraded  bool
}

type tickMsg time.Time

func doTick() tea.Cmd {
	return tea.Tick(time.Millisecond*30, func(t time.Time) tea.Msg {
		return tickMsg(t)
	})
}

func newInput(echo textinput.EchoMode) textinput.Model {
	ti := textinput.New()
	ti.Prompt = ""
	ti.EchoMode = echo
	ti.Styles.Focused.Text = lipgloss.NewStyle().Foreground(lipgloss.Color(fgHex))
	return ti
}

func initialModel(conf Config, testMode bool) model {
	m := model{
		usernameInput: newInput(textinput.EchoNormal),
		passwordInput: newInput(textinput.EchoPassword),
		spinner:       spinner.New(),
		conf:          conf,
		testMode:      testMode,
		width:         80,
		height:        24,
		fadeEnd:       fadeTotal(conf.ASCII),
	}
	m.spinner.Spinner = spinner.Points
	m.spinner.Style = lipgloss.NewStyle().Foreground(lipgloss.Color(accentHex))

	if !testMode {
		client, err := ipc.NewClient()
		if err != nil {
			logDebug("FATAL: IPC client creation failed: %v", err)
			fmt.Fprintf(os.Stderr, "FATAL: failed to create IPC client: %v\n", err)
			fmt.Fprintf(os.Stderr, "This greeter must be run by greetd with GREETD_SOCK set.\n")
			os.Exit(1)
		}
		m.ipcClient = client
	}

	if conf.User != "" {
		m.usernameInput.SetValue(conf.User)
		m.setFocus(FocusPassword)
	} else {
		m.setFocus(FocusUsername)
	}
	return m
}

func (m *model) setFocus(f FocusState) tea.Cmd {
	m.focus = f
	if f == FocusUsername {
		m.passwordInput.Blur()
		m.usernameInput.Focus()
	} else {
		m.usernameInput.Blur()
		m.passwordInput.Focus()
	}
	return textinput.Blink
}

func (m model) Init() tea.Cmd {
	return tea.Batch(textinput.Blink, m.spinner.Tick, doTick(), tea.RequestUniformKeyLayout)
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	var cmds []tea.Cmd

	switch msg := msg.(type) {
	case tea.KeyboardEnhancementsMsg:
		// Non-US layouts need alternate-key and associated-text reporting to
		// type shifted characters correctly; mode 2 adds flags without
		// dropping the lock-key reporting used for CapsLock detection.
		if !m.kittyUpgraded {
			m.kittyUpgraded = true
			flags := ansi.KittyReportAlternateKeys | ansi.KittyReportAssociatedKeys
			return m, tea.Raw(ansi.KittyKeyboard(flags, 2))
		}

	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height
		return m, nil

	case tickMsg:
		if m.fadeFrame < m.fadeEnd {
			m.fadeFrame++
			cmds = append(cmds, doTick())
		}

	case string:
		if msg == "success" {
			return m, tea.Quit
		}

	case error:
		m.errorMessage = msg.Error()
		m.failedAttempts++
		m.loading = false
		m.passwordInput.SetValue("")
		return m, m.setFocus(FocusPassword)

	case tea.KeyMsg:
		m.capsLockOn = (msg.Key().Mod & tea.ModCapsLock) != 0
		newModel, cmd := m.handleKey(msg)
		m = newModel
		cmds = append(cmds, cmd)
	}

	if m.loading {
		var cmd tea.Cmd
		m.spinner, cmd = m.spinner.Update(msg)
		cmds = append(cmds, cmd)
	} else {
		var cmd tea.Cmd
		if m.focus == FocusUsername {
			m.usernameInput, cmd = m.usernameInput.Update(msg)
			if m.errorMessage != "" && m.usernameInput.Value() != "" {
				m.errorMessage = ""
			}
		} else {
			m.passwordInput, cmd = m.passwordInput.Update(msg)
			if m.errorMessage != "" && m.passwordInput.Value() != "" {
				m.errorMessage = ""
			}
		}
		cmds = append(cmds, cmd)
	}

	return m, tea.Batch(cmds...)
}

func (m model) handleKey(msg tea.KeyMsg) (model, tea.Cmd) {
	switch msg.String() {
	case "ctrl+c":
		if m.ipcClient == nil {
			return m, tea.Quit
		}
		return m, nil

	case "f6", "f7":
		if m.testMode {
			return m, tea.Quit
		}
		action := "poweroff"
		if msg.String() == "f7" {
			action = "reboot"
		}
		// Stay alive: systemd 260+ kills all processes in the session scope
		// on greeter exit.
		exec.Command("systemctl", action).Start()
		m.loading = true
		return m, nil
	}

	if m.loading {
		return m, nil
	}

	switch msg.String() {
	case "tab", "shift+tab":
		if m.focus == FocusUsername {
			return m, m.setFocus(FocusPassword)
		}
		return m, m.setFocus(FocusUsername)

	case "esc":
		if m.focus == FocusPassword {
			m.passwordInput.SetValue("")
			return m, m.setFocus(FocusUsername)
		}

	case "enter":
		if m.focus == FocusUsername {
			return m, m.setFocus(FocusPassword)
		}
		username := m.usernameInput.Value()
		password := m.passwordInput.Value()
		logDebug("authentication attempt for user: %s", username)
		if m.testMode {
			fmt.Println("Test mode: auth successful")
			return m, tea.Quit
		}
		m.loading = true
		return m, m.authenticate(username, password)
	}

	return m, nil
}

func (m model) authenticate(username, password string) tea.Cmd {
	return func() tea.Msg {
		c := m.ipcClient
		fail := func(err error) tea.Msg {
			c.CancelSession()
			return err
		}

		if err := c.CreateSession(username); err != nil {
			return err
		}
		resp, err := c.ReceiveResponse()
		if err != nil {
			return fail(err)
		}
		if errResp, ok := resp.(ipc.Error); ok {
			return fail(fmt.Errorf("authentication failed: %s - %s", errResp.ErrorType, errResp.Description))
		}
		if _, ok := resp.(ipc.AuthMessage); !ok {
			return fail(fmt.Errorf("expected auth message or error, got %T", resp))
		}

		if err := c.PostAuthMessageResponse(&password); err != nil {
			return fail(err)
		}
		resp, err = c.ReceiveResponse()
		if err != nil {
			return fail(err)
		}
		if errResp, ok := resp.(ipc.Error); ok {
			return fail(fmt.Errorf("authentication failed: %s - %s", errResp.ErrorType, errResp.Description))
		}
		if _, ok := resp.(ipc.Success); !ok {
			return fail(fmt.Errorf("expected success or error, got %T", resp))
		}

		if err := c.StartSession(strings.Fields(m.conf.Exec), []string{}); err != nil {
			return fail(err)
		}
		return "success"
	}
}

func main() {
	var showVersion, testMode bool
	var conf Config
	var asciiPath, bg, fg, accent string
	flag.BoolVar(&showVersion, "version", false, "Show version information")
	flag.BoolVar(&showVersion, "v", false, "Show version information (shorthand)")
	flag.BoolVar(&testMode, "test", false, "Enable test mode (no actual authentication)")
	flag.StringVar(&conf.Exec, "exec", "", "Command to launch after successful login")
	flag.StringVar(&conf.User, "user", "", "Prefill this username and focus the password field")
	flag.StringVar(&asciiPath, "ascii", defaultAsciiPath, "Path to ASCII art file")
	flag.StringVar(&bg, "bg", "", "Background color (hex)")
	flag.StringVar(&fg, "fg", "", "Text color (hex)")
	flag.StringVar(&accent, "accent", "", "Accent color (hex)")
	flag.Parse()

	if showVersion {
		fmt.Printf("gloxwaldgreet %s\nCommit: %s\nBuilt: %s\n", Version, GitCommit, BuildDate)
		os.Exit(0)
	}

	if testMode && os.Getenv("GREETD_SOCK") != "" {
		fmt.Fprintf(os.Stderr, "SECURITY ERROR: test mode cannot be enabled in production (GREETD_SOCK is set)\n")
		os.Exit(1)
	}

	initDebugLog()
	logDebug("=== gloxwaldgreet %s started ===", Version)

	applyColors(bg, fg, accent)
	if data, err := os.ReadFile(asciiPath); err == nil {
		conf.ASCII = strings.TrimRight(string(data), " \n")
	} else {
		logDebug("ascii load failed: %v", err)
	}
	if testMode && conf.Exec == "" {
		conf.Exec = "Hyprland"
	}

	opts := []tea.ProgramOption{}
	if _, err := os.OpenFile("/dev/tty", os.O_RDWR, 0); err == nil {
		opts = append(opts, tea.WithAltScreen())
	}

	if _, err := tea.NewProgram(initialModel(conf, testMode), opts...).Run(); err != nil {
		fmt.Printf("Error: %v\n", err)
		os.Exit(1)
	}
}
