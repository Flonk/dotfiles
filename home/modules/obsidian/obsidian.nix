{
  pkgs,
  config,
  lib,
  ...
}:
let
  c = config.theme.color;
  fs = config.theme.fontSize;
  ff = config.theme.fontFamily;

  themeCss = ''
    /* ===== Obsidian — Flo base (scoped to theme root) ===== */

    .theme-dark, .theme-light {
      /* Fonts */
      --font-interface: "${ff.ui}", system-ui, sans-serif;
      --font-text:      "${ff.ui}", system-ui, sans-serif;
      --font-monospace: "${ff.mono}", ui-monospace, monospace;

      /* Surfaces */
      --background-primary:         ${c.app150};
      --background-secondary:       ${c.app200};
      --background-modifier-hover:  ${c.app200};
      --background-modifier-border: ${c.app200};

      /* Text */
      --text-normal:  ${c.text};
      --text-muted:   ${c.app950}88;
      --text-accent:  ${c.wm800};

      /* Sizes */
      --h1-size: ${toString fs.huge}px;
      --h2-size: ${toString fs.bigger}px;
      --h3-size: ${toString fs.big}px;
      --font-text-size: ${toString fs.normal}px;
      --line-height-normal: 1.6;

      /* Interactive */
      --interactive-normal:        ${c.app200};
      --interactive-hover:         ${c.app200};
      --interactive-accent:        ${c.wm800};
      --interactive-accent-hover:  ${c.wm800};

      /* Selection (match VS Code) */
      --text-selection: ${c.app800}33;

      /* Tabs (neutral hover like idle) */
      --tab-background: var(--background-primary);
      --tab-background-active: var(--background-primary);
      --tab-background-hover: var(--background-primary);
      --tab-text-color: var(--text-normal);
      --tab-text-color-focused: var(--text-normal);
      --tab-outline-color: transparent;
      --tab-container-background: var(--background-primary);
      --tab-divider-color: var(--background-modifier-border);
    }

    /* Editor + preview */
    .theme-dark .cm-editor,
    .theme-light .cm-editor,
    .theme-dark .markdown-source-view,
    .theme-light .markdown-source-view,
    .theme-dark .cm-scroller,
    .theme-light .cm-scroller,
    .theme-dark .markdown-preview-view,
    .theme-light .markdown-preview-view {
      background:   var(--background-primary) !important;
      color:        var(--text-normal) !important;
      font-size:    var(--font-text-size) !important;
      line-height:  var(--line-height-normal) !important;
      font-family:  var(--font-text) !important;
    }

    /* Sidebars / panes / tabs (match VS Code: same bg as editor, with borders) */
    .theme-dark .workspace,
    .theme-light .workspace,
    .theme-dark .workspace-split,
    .theme-light .workspace-split,
    .theme-dark .workspace-leaf-content,
    .theme-light .workspace-leaf-content,
    .theme-dark .workspace-ribbon,
    .theme-light .workspace-ribbon,
    .theme-dark .mod-left-split,
    .theme-light .mod-left-split,
    .theme-dark .mod-right-split,
    .theme-light .mod-right-split,
    .theme-dark .mod-root .workspace-tabs,
    .theme-light .mod-root .workspace-tabs {
      background: var(--background-primary) !important;
    }

    /* Borders between side panes and content */
    .theme-dark .mod-left-split,
    .theme-light .mod-left-split,
    .theme-dark .workspace-ribbon.mod-left,
    .theme-light .workspace-ribbon.mod-left {
      border-right: 1px solid var(--background-modifier-border) !important;
    }
    .theme-dark .mod-right-split,
    .theme-light .mod-right-split,
    .theme-dark .workspace-ribbon.mod-right,
    .theme-light .workspace-ribbon.mod-right {
      border-left: 1px solid var(--background-modifier-border) !important;
    }

    /* Sidebar tree: hover/selection (match VS Code list.* = app200) */
    .theme-dark .nav-file-title:hover,
    .theme-light .nav-file-title:hover,
    .theme-dark .nav-folder-title:hover,
    .theme-light .nav-folder-title:hover,
    .theme-dark .nav-file-title.is-selected,
    .theme-light .nav-file-title.is-selected,
    .theme-dark .nav-folder-title.is-selected,
    .theme-light .nav-folder-title.is-selected,
    .theme-dark .nav-file-title.is-active,
    .theme-light .nav-file-title.is-active,
    .theme-dark .nav-folder-title.is-active,
    .theme-light .nav-folder-title.is-active {
      background-color: var(--background-modifier-hover) !important; /* app200 */
    }

    /* Top bar tabs/header: keep hover same as idle */
    .theme-dark .workspace-tab-header:hover,
    .theme-light .workspace-tab-header:hover,
    .theme-dark .workspace-tab-header.is-active:hover,
    .theme-light .workspace-tab-header.is-active:hover,
    .theme-dark .view-header:hover,
    .theme-light .view-header:hover,
    .theme-dark .view-actions .clickable-icon:hover,
    .theme-light .view-actions .clickable-icon:hover,
    .theme-dark .titlebar:hover,
    .theme-light .titlebar:hover {
      background: var(--background-primary) !important;
      box-shadow: none !important;
      filter: none !important;
    }
    .theme-dark .workspace-tab-header:hover .workspace-tab-header-inner,
    .theme-light .workspace-tab-header:hover .workspace-tab-header-inner,
    .theme-dark .workspace-tab-header.is-active:hover .workspace-tab-header-inner,
    .theme-light .workspace-tab-header.is-active:hover .workspace-tab-header-inner {
      background: var(--background-primary) !important;
    }

    /* Top bar (tabs/titlebar) — make hover identical to idle */
    .theme-dark .mod-root .workspace-tabs .workspace-tab-header-container:hover,
    .theme-light .mod-root .workspace-tabs .workspace-tab-header-container:hover,
    .theme-dark .mod-root .workspace-tabs .workspace-tab-header:hover,
    .theme-light .mod-root .workspace-tabs .workspace-tab-header:hover,
    .theme-dark .mod-root .workspace-tabs .workspace-tab-header.is-active:hover,
    .theme-light .mod-root .workspace-tabs .workspace-tab-header.is-active:hover,
    .theme-dark .mod-root .workspace-tabs .workspace-tab-header:hover .workspace-tab-header-inner,
    .theme-light .mod-root .workspace-tabs .workspace-tab-header:hover .workspace-tab-header-inner,
    .theme-dark .mod-root .mod-top .workspace-tabs .workspace-tab-header:hover,
    .theme-light .mod-root .mod-top .workspace-tabs .workspace-tab-header:hover,
    .theme-dark .mod-root .mod-top .workspace-tabs .workspace-tab-container:hover,
    .theme-light .mod-root .mod-top .workspace-tabs .workspace-tab-container:hover {
      background: var(--background-primary) !important;
      box-shadow: none !important;
      filter: none !important;
    }

    /* Keep divider subtle and consistent */
    .theme-dark .mod-root .workspace-tabs .workspace-tab-header-container,
    .theme-light .mod-root .workspace-tabs .workspace-tab-header-container {
      border-color: var(--tab-divider-color) !important;
    }

    /* Remove hover tint on icons in the top bars */
    .theme-dark .titlebar .clickable-icon:hover,
    .theme-light .titlebar .clickable-icon:hover,
    .theme-dark .mod-root .workspace-tabs .clickable-icon:hover,
    .theme-light .mod-root .workspace-tabs .clickable-icon:hover,
    .theme-dark .view-header .clickable-icon:hover,
    .theme-light .view-header .clickable-icon:hover {
      background-color: transparent !important;
      box-shadow: none !important;
      filter: none !important;
    }

    /* Headings */
    .theme-dark .markdown-preview-view h1,
    .theme-light .markdown-preview-view h1,
    .theme-dark .markdown-source-view h1,
    .theme-light .markdown-source-view h1,
    .theme-dark .cm-heading-1,
    .theme-light .cm-heading-1 { font-size: var(--h1-size) !important; }

    .theme-dark .markdown-preview-view h2,
    .theme-light .markdown-preview-view h2,
    .theme-dark .markdown-source-view h2,
    .theme-light .markdown-source-view h2,
    .theme-dark .cm-heading-2,
    .theme-light .cm-heading-2 { font-size: var(--h2-size) !important; }

    .theme-dark .markdown-preview-view h3,
    .theme-light .markdown-preview-view h3,
    .theme-dark .markdown-source-view h3,
    .theme-light .markdown-source-view h3,
    .theme-dark .cm-heading-3,
    .theme-light .cm-heading-3 { font-size: var(--h3-size) !important; }

    /* Links */
    .theme-dark a, .theme-light a,
    .theme-dark .cm-link, .theme-light .cm-link,
    .theme-dark .internal-link, .theme-light .internal-link {
      color: var(--text-accent) !important;
    }

    /* Selection colors (match VS Code) */
    /* Preview/native selection */
    .theme-dark ::selection,
    .theme-light ::selection { background: var(--text-selection) !important; }

    /* CodeMirror selection layers */
    .theme-dark .cm-selectionBackground,
    .theme-light .cm-selectionBackground { background-color: var(--text-selection) !important; }
    .theme-dark .cm-content ::selection,
    .theme-light .cm-content ::selection { background: var(--text-selection) !important; }

    /* Optional: reader width */
    .theme-dark .markdown-preview-view,
    .theme-light .markdown-preview-view { max-width: 78ch; }
  '';
in
{
  home.packages = with pkgs; [ obsidian ];

  home.file."Documents/Vault/.obsidian/snippets/style.css".text = lib.mkForce themeCss;
}
