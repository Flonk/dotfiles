package main

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"sort"
	"strings"
	"syscall"

	"github.com/charmbracelet/bubbles/textinput"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
	"github.com/charmbracelet/x/ansi"
)

type Entry struct {
	Command []string `json:"command"`
	Title   string   `json:"title"`
	Usage   string   `json:"usage"`
	Pinned  bool     `json:"pinned"`
	Preview bool     `json:"preview"`
}

type Manifest struct {
	Installation string            `json:"installation"`
	Theme        map[string]string `json:"theme"`
	Entries      []Entry           `json:"entries"`
	Banners      map[string]string `json:"banners"`
}

type Node struct {
	Name     string
	Path     []string
	Entry    *Entry
	Children []*Node
	Parent   *Node
	Expanded bool
}

func (n *Node) key() string { return strings.Join(n.Path, " ") }

func (n *Node) pinned() bool { return n.Entry != nil && n.Entry.Pinned }

func (n *Node) child(name string) *Node {
	for _, c := range n.Children {
		if c.Name == name {
			return c
		}
	}
	c := &Node{Name: name, Path: append(append([]string{}, n.Path...), name), Parent: n}
	n.Children = append(n.Children, c)
	return c
}

func buildTree(entries []Entry) *Node {
	root := &Node{Expanded: true}
	for i := range entries {
		n := root
		for _, w := range entries[i].Command {
			n = n.child(w)
		}
		n.Entry = &entries[i]
	}
	var sortRec func(*Node)
	sortRec = func(n *Node) {
		sort.Slice(n.Children, func(a, b int) bool {
			pa, pb := n.Children[a].pinned(), n.Children[b].pinned()
			if pa != pb {
				return pa
			}
			return n.Children[a].Name < n.Children[b].Name
		})
		for _, c := range n.Children {
			sortRec(c)
		}
	}
	sortRec(root)
	return root
}

type row struct {
	node   *Node
	prefix string
}

type styles struct {
	accent, base00, base01, base03, base04, base05, base06, base0B lipgloss.Color
}

func newStyles(t map[string]string) styles {
	get := func(k, d string) lipgloss.Color {
		if v, ok := t[k]; ok && v != "" {
			return lipgloss.Color(v)
		}
		return lipgloss.Color(d)
	}
	return styles{
		accent: get("accent", "#1d9eb6"),
		base00: get("base00", "#000000"),
		base01: get("base01", "#1a1a1a"),
		base03: get("base03", "#666666"),
		base04: get("base04", "#888888"),
		base05: get("base05", "#cccccc"),
		base06: get("base06", "#e0e0e0"),
		base0B: get("base0B", "#98c379"),
	}
}

type mode int

const (
	browsing mode = iota
	filtering
	arguing
)

type model struct {
	m        Manifest
	st       styles
	root     *Node
	rows     []row
	cursor   int
	offset   int
	width    int
	height   int
	mode     mode
	filter   textinput.Model
	args     textinput.Model
	run      []string
	previews map[string]string
	runArgs  string
	selected *Node
}

func newModel(m Manifest) model {
	st := newStyles(m.Theme)
	f := textinput.New()
	f.Prompt = "/"
	f.PromptStyle = lipgloss.NewStyle().Foreground(st.accent)
	f.TextStyle = lipgloss.NewStyle().Foreground(st.base06)
	f.Cursor.Style = lipgloss.NewStyle().Foreground(st.accent)
	a := textinput.New()
	a.TextStyle = lipgloss.NewStyle().Foreground(st.base06)
	a.Cursor.Style = lipgloss.NewStyle().Foreground(st.accent)
	md := model{m: m, st: st, root: buildTree(m.Entries), filter: f, args: a, previews: map[string]string{}}
	md.refresh()
	return md
}

func matches(n *Node, q string) bool {
	if q == "" {
		return true
	}
	hay := strings.ToLower(n.key())
	if n.Entry != nil {
		hay += " " + strings.ToLower(n.Entry.Title)
	}
	return strings.Contains(hay, strings.ToLower(q))
}

func anyMatch(n *Node, q string) bool {
	if matches(n, q) {
		return true
	}
	for _, c := range n.Children {
		if anyMatch(c, q) {
			return true
		}
	}
	return false
}

func (m *model) refresh() {
	q := strings.TrimSpace(m.filter.Value())
	var rows []row
	var walk func(n *Node, lead string)
	walk = func(n *Node, lead string) {
		var kids []*Node
		for _, c := range n.Children {
			if q == "" || anyMatch(c, q) {
				kids = append(kids, c)
			}
		}
		for i, c := range kids {
			last := i == len(kids)-1
			branch, cont := "├─ ", "│  "
			if last {
				branch, cont = "└─ ", "   "
			}
			rows = append(rows, row{node: c, prefix: lead + branch})
			if len(c.Children) > 0 && (c.Expanded || q != "") {
				walk(c, lead+cont)
			}
		}
	}
	walk(m.root, "")
	m.rows = rows
	if m.selected != nil {
		for i, r := range rows {
			if r.node == m.selected {
				m.cursor = i
			}
		}
	}
	if m.cursor >= len(rows) {
		m.cursor = len(rows) - 1
	}
	if m.cursor < 0 {
		m.cursor = 0
	}
	m.sync()
}

func (m *model) sync() {
	if len(m.rows) > 0 {
		m.selected = m.rows[m.cursor].node
	} else {
		m.selected = nil
	}
	h := m.listHeight()
	if m.cursor < m.offset {
		m.offset = m.cursor
	}
	if h > 0 && m.cursor >= m.offset+h {
		m.offset = m.cursor - h + 1
	}
	if m.offset < 0 {
		m.offset = 0
	}
}

func (m model) listHeight() int { return max(m.height-3, 1) }

func (m *model) jumpToMatch() {
	q := strings.TrimSpace(m.filter.Value())
	if q == "" {
		return
	}
	best := -1
	for i, r := range m.rows {
		if matches(r.node, q) {
			if r.node.Entry != nil {
				best = i
				break
			}
			if best < 0 {
				best = i
			}
		}
	}
	if best >= 0 {
		m.cursor = best
		m.sync()
	}
}

func (m *model) move(d int) {
	if len(m.rows) == 0 {
		return
	}
	m.cursor = max(0, min(len(m.rows)-1, m.cursor+d))
	m.sync()
}

type previewMsg struct{ key, out string }

func runPreview(e Entry) tea.Cmd {
	return func() tea.Msg {
		c := exec.Command("t3os", e.Command...)
		c.Env = append(os.Environ(), "T3OS_COLOR=1")
		out, err := c.Output()
		s := strings.TrimRight(string(out), "\n")
		if err != nil && s == "" {
			s = err.Error()
		}
		return previewMsg{key: strings.Join(e.Command, " "), out: s}
	}
}

func (m model) Init() tea.Cmd {
	var cmds []tea.Cmd
	for _, e := range m.m.Entries {
		if e.Preview {
			cmds = append(cmds, runPreview(e))
		}
	}
	return tea.Batch(cmds...)
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case previewMsg:
		m.previews[msg.key] = msg.out
		return m, nil
	case tea.WindowSizeMsg:
		m.width, m.height = msg.Width, msg.Height
		m.sync()
		return m, nil
	case tea.MouseMsg:
		if m.mode != browsing {
			return m, nil
		}
		switch msg.Button {
		case tea.MouseButtonWheelUp:
			m.move(-1)
		case tea.MouseButtonWheelDown:
			m.move(1)
		case tea.MouseButtonLeft:
			if msg.Action != tea.MouseActionPress || msg.X >= m.leftWidth() {
				break
			}
			i := msg.Y - 1 + m.offset
			if i >= 0 && i < len(m.rows) {
				if i == m.cursor {
					return m.activate()
				}
				m.cursor = i
				m.sync()
			}
		}
		return m, nil
	case tea.KeyMsg:
		if m.mode == browsing && msg.Type == tea.KeyRunes && len(msg.Runes) > 1 {
			var cmds []tea.Cmd
			var cur tea.Model = m
			for _, r := range msg.Runes {
				var cmd tea.Cmd
				cur, cmd = cur.Update(tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune{r}})
				cmds = append(cmds, cmd)
			}
			return cur, tea.Batch(cmds...)
		}
		switch m.mode {
		case filtering:
			switch msg.String() {
			case "esc":
				m.filter.SetValue("")
				m.filter.Blur()
				m.mode = browsing
				m.refresh()
				return m, nil
			case "enter":
				m.filter.Blur()
				m.mode = browsing
				return m, nil
			case "up", "ctrl+p", "ctrl+k":
				m.move(-1)
				return m, nil
			case "down", "ctrl+n", "ctrl+j":
				m.move(1)
				return m, nil
			}
			var cmd tea.Cmd
			m.filter, cmd = m.filter.Update(msg)
			m.selected = nil
			m.cursor = 0
			m.refresh()
			m.jumpToMatch()
			return m, cmd
		case arguing:
			switch msg.String() {
			case "esc":
				m.args.Blur()
				m.mode = browsing
				return m, nil
			case "enter":
				m.run = m.selected.Path
				m.runArgs = m.args.Value()
				return m, tea.Quit
			}
			var cmd tea.Cmd
			m.args, cmd = m.args.Update(msg)
			return m, cmd
		}
		switch msg.String() {
		case "q", "ctrl+c", "esc":
			if msg.String() == "esc" && m.filter.Value() != "" {
				m.filter.SetValue("")
				m.refresh()
				return m, nil
			}
			return m, tea.Quit
		case "up", "k":
			m.move(-1)
		case "down", "j":
			m.move(1)
		case "pgup", "ctrl+u":
			m.move(-m.listHeight() / 2)
		case "pgdown", "ctrl+d":
			m.move(m.listHeight() / 2)
		case "home", "g":
			m.move(-len(m.rows))
		case "end", "G":
			m.move(len(m.rows))
		case "right", "l":
			if n := m.selected; n != nil && len(n.Children) > 0 {
				if n.Expanded {
					m.move(1)
				} else {
					n.Expanded = true
					m.refresh()
				}
			}
		case "left", "h":
			if n := m.selected; n != nil {
				if len(n.Children) > 0 && n.Expanded {
					n.Expanded = false
				} else if n.Parent != nil && n.Parent != m.root {
					n.Parent.Expanded = false
					m.selected = n.Parent
				}
				m.refresh()
			}
		case "E":
			var all func(*Node, bool)
			all = func(n *Node, v bool) {
				for _, c := range n.Children {
					c.Expanded = v
					all(c, v)
				}
			}
			open := false
			for _, c := range m.root.Children {
				if len(c.Children) > 0 && !c.Expanded {
					open = true
				}
			}
			all(m.root, open)
			m.refresh()
		case "/":
			m.mode = filtering
			return m, m.filter.Focus()
		case "a", "tab":
			if m.selected != nil && m.selected.Entry != nil {
				m.mode = arguing
				m.args.Prompt = "t3os " + m.selected.key() + " "
				m.args.PromptStyle = lipgloss.NewStyle().Foreground(m.st.accent).Bold(true)
				m.args.SetValue("")
				return m, m.args.Focus()
			}
		case "enter", " ":
			return m.activate()
		}
	}
	return m, nil
}

func (m model) activate() (tea.Model, tea.Cmd) {
	n := m.selected
	if n == nil {
		return m, nil
	}
	if n.Entry != nil {
		m.run = n.Path
		return m, tea.Quit
	}
	n.Expanded = !n.Expanded
	m.refresh()
	return m, nil
}

func upper(s string) string { return strings.ToUpper(s) }

func (m model) leftWidth() int {
	w := 18
	for _, r := range m.rows {
		w = max(w, lipgloss.Width(r.prefix)+lipgloss.Width(r.node.Name)+6)
	}
	return min(w, max(m.width*2/5, 20))
}

func (m model) box(title string, lines []string, w, h int, border lipgloss.Color) string {
	bs := lipgloss.NewStyle().Foreground(border)
	ts := lipgloss.NewStyle().Foreground(border).Bold(true)
	inner := w - 2
	label := ""
	if title != "" {
		label = " " + upper(title) + " "
	}
	label = ansi.Truncate(label, max(inner-2, 0), "")
	top := bs.Render("╭─") + ts.Render(label) + bs.Render(strings.Repeat("─", max(inner-1-lipgloss.Width(label), 0))+"╮")
	out := []string{top}
	for i := 0; i < h-2; i++ {
		l := ""
		if i < len(lines) {
			l = lines[i]
		}
		l = ansi.Truncate(l, inner, "…")
		pad := max(inner-lipgloss.Width(l), 0)
		out = append(out, bs.Render("│")+l+strings.Repeat(" ", pad)+bs.Render("│"))
	}
	out = append(out, bs.Render("╰"+strings.Repeat("─", max(inner, 0))+"╯"))
	return strings.Join(out, "\n")
}

func (m model) treeLines(w int) []string {
	glyph := lipgloss.NewStyle().Foreground(m.st.base03)
	name := lipgloss.NewStyle().Foreground(m.st.base05)
	group := lipgloss.NewStyle().Foreground(m.st.base06).Bold(true)
	hit := lipgloss.NewStyle().Foreground(m.st.accent)
	sel := lipgloss.NewStyle().Background(m.st.accent).Foreground(m.st.base00).Bold(true)
	q := strings.TrimSpace(m.filter.Value())
	h := m.listHeight()
	var lines []string
	for i := m.offset; i < len(m.rows) && i < m.offset+h; i++ {
		r := m.rows[i]
		n := r.node
		mark := "  "
		if len(n.Children) > 0 {
			mark = "▸ "
			if n.Expanded || q != "" {
				mark = "▾ "
			}
		}
		if i == m.cursor {
			text := " " + r.prefix + mark + n.Name
			pad := max(w-lipgloss.Width(text), 0)
			lines = append(lines, sel.Render(text+strings.Repeat(" ", pad)))
			continue
		}
		ns := name
		if len(n.Children) > 0 {
			ns = group
		}
		if q != "" && matches(n, q) {
			ns = hit.Bold(len(n.Children) > 0)
		}
		lines = append(lines, " "+glyph.Render(r.prefix)+glyph.Render(mark)+ns.Render(n.Name))
	}
	if len(m.rows) == 0 {
		lines = append(lines, " "+glyph.Render("no matches"))
	}
	return lines
}

func (m model) inline(s string, base lipgloss.Style) string {
	code := lipgloss.NewStyle().Foreground(m.st.base0B).Background(m.st.base01)
	parts := strings.Split(s, "`")
	var b strings.Builder
	for i, p := range parts {
		if i%2 == 1 && i < len(parts)-1 {
			b.WriteString(code.Render(p))
		} else {
			if i%2 == 1 {
				p = "`" + p
			}
			b.WriteString(base.Render(p))
		}
	}
	return b.String()
}

func (m model) wrap(s string, w int, base lipgloss.Style) []string {
	var out []string
	for _, l := range strings.Split(ansi.Wordwrap(s, w, ""), "\n") {
		out = append(out, m.inline(l, base))
	}
	return out
}

func (m model) detailLines(w int) []string {
	n := m.selected
	if n == nil {
		return nil
	}
	accent := lipgloss.NewStyle().Foreground(m.st.accent)
	title := lipgloss.NewStyle().Foreground(m.st.base06).Bold(true)
	text := lipgloss.NewStyle().Foreground(m.st.base05)
	muted := lipgloss.NewStyle().Foreground(m.st.base03)
	label := lipgloss.NewStyle().Foreground(m.st.base04).Bold(true)
	cmd := lipgloss.NewStyle().Foreground(m.st.base00).Background(m.st.accent).Bold(true)
	inner := w - 4
	var lines []string
	add := func(ls ...string) {
		for _, l := range ls {
			lines = append(lines, "  "+l)
		}
	}
	lines = append(lines, "")
	bk := n.key()
	if n.pinned() {
		bk = "t3os"
	}
	banner := strings.TrimRight(m.m.Banners[bk], "\n")
	bw := 0
	for _, l := range strings.Split(banner, "\n") {
		bw = max(bw, lipgloss.Width(l))
	}
	if banner != "" && bw <= inner {
		for _, l := range strings.Split(banner, "\n") {
			add(accent.Render(l))
		}
	} else {
		add(accent.Bold(true).Render(upper(n.key())))
	}
	add("")
	if n.Entry != nil && n.Entry.Preview {
		out, ok := m.previews[n.key()]
		if !ok {
			out = muted.Render("loading…")
		}
		add(strings.Split(out, "\n")...)
		add("", cmd.Render(" $ t3os "+n.key()+" "))
		return lines
	}
	if n.Entry != nil {
		add(m.wrap(n.Entry.Title, inner, title)...)
	} else {
		add(title.Render(fmt.Sprintf("%d %s commands", len(n.Children), n.key())))
	}
	add("")
	add(cmd.Render(" $ t3os " + n.key() + " "))
	if n.Entry != nil && strings.TrimSpace(n.Entry.Usage) != "" {
		add("", label.Render(upper("usage")), "")
		add(m.wrap(n.Entry.Usage, inner, text)...)
	}
	if len(n.Children) > 0 {
		add("", label.Render(upper("subcommands")), "")
		nw := 0
		for _, c := range n.Children {
			nw = max(nw, lipgloss.Width(c.Name))
		}
		for _, c := range n.Children {
			desc := ""
			if c.Entry != nil {
				desc = c.Entry.Title
			} else {
				desc = fmt.Sprintf("%d commands", len(c.Children))
			}
			pad := strings.Repeat(" ", nw-lipgloss.Width(c.Name)+2)
			add(accent.Render(c.Name) + pad + muted.Render(ansi.Truncate(desc, max(inner-nw-2, 0), "…")))
		}
	}
	return lines
}

func (m model) key(k, desc string) string {
	return lipgloss.NewStyle().Foreground(m.st.accent).Bold(true).Render(k) + " " +
		lipgloss.NewStyle().Foreground(m.st.base03).Render(desc)
}

func (m model) View() string {
	if m.width == 0 {
		return ""
	}
	lw := m.leftWidth()
	rw := max(m.width-lw, 10)
	bodyH := max(m.height-1, 3)
	treeTitle := "commands"
	if q := m.filter.Value(); q != "" {
		treeTitle = "filter"
	}
	left := m.box(treeTitle, m.treeLines(lw-2), lw, bodyH, m.st.accent)
	rightTitle := ""
	if m.selected != nil {
		rightTitle = m.selected.key()
	}
	right := m.box(rightTitle, m.detailLines(rw), rw, bodyH, m.st.base03)
	body := lipgloss.JoinHorizontal(lipgloss.Top, left, right)

	var footer string
	switch m.mode {
	case filtering:
		footer = " " + m.filter.View()
	case arguing:
		footer = " " + m.args.View()
	default:
		parts := []string{m.key("↑↓", "move"), m.key("←→", "fold"), m.key("⏎", "run"), m.key("a", "args"), m.key("/", "filter"), m.key("E", "expand all"), m.key("q", "quit")}
		if q := m.filter.Value(); q != "" {
			parts = append([]string{lipgloss.NewStyle().Foreground(m.st.accent).Render("/" + q)}, parts...)
		}
		footer = " " + strings.Join(parts, "  ")
	}
	footer = ansi.Truncate(footer, m.width, "")
	return body + "\n" + footer
}

func main() {
	if len(os.Args) < 2 {
		fmt.Fprintln(os.Stderr, "usage: t3os-tui <manifest.json>")
		os.Exit(2)
	}
	b, err := os.ReadFile(os.Args[1])
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	var man Manifest
	if err := json.Unmarshal(b, &man); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	res, err := tea.NewProgram(newModel(man), tea.WithAltScreen(), tea.WithMouseCellMotion()).Run()
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	final := res.(model)
	if final.run == nil {
		return
	}
	line := "t3os " + strings.Join(final.run, " ")
	if a := strings.TrimSpace(final.runArgs); a != "" {
		line += " " + a
	}
	fmt.Println(lipgloss.NewStyle().Foreground(final.st.accent).Bold(true).Render("$ " + line))
	sh, err := exec.LookPath("sh")
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	if err := syscall.Exec(sh, []string{"sh", "-c", "exec " + line}, os.Environ()); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
