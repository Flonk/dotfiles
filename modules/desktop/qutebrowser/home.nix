{
  config,
  lib,
  pkgs,
  ...
}:
let
  # direction: "left" | "right" | "up" | "down"
  # left/right: move within tab bar first, give to neighbor qutebrowser at edge
  # up/down: always give to nearest qutebrowser in that direction (or new window)
  mkTabMoveScript = direction:
    let
      isLeft = direction == "left";
      isRight = direction == "right";
      isUp = direction == "up";
      isHorizontal = isLeft || isRight;
      coordIdx = if isHorizontal then "0" else "1";
      filterLess = isLeft || isUp;  # smaller coord = left or up
      edgeCheck = if isLeft then "_idx <= 0"
                  else if isRight then "_idx >= _cnt - 1"
                  else "True";
      moveCmd = if isLeft then "tab-move -"
                else if isRight then "tab-move +"
                else "noop";
      sortReverse = if filterLess then "True" else "False";
    in
    pkgs.writeText "tab-move-${direction}-or-detach.py" ''
      import json
      import subprocess
      from qutebrowser.utils import objreg
      from qutebrowser.commands import runners

      _wid = None
      for _w in objreg.window_registry:
          if objreg.window_registry[_w].isActiveWindow():
              _wid = _w
              break
      if _wid is None:
          _wid = next(iter(objreg.window_registry))

      _tb = objreg.get('tabbed-browser', scope='window', window=_wid)
      _idx = _tb.widget.currentIndex()
      _cnt = _tb.widget.count()
      _r = runners.CommandRunner(_wid)

      if not (${edgeCheck}):
          _r.run('${moveCmd}')
      else:
          _gave = False
          try:
              _active = json.loads(subprocess.check_output(
                  ['hyprctl', 'activewindow', '-j'],
              ))
              _clients = json.loads(subprocess.check_output(
                  ['hyprctl', 'clients', '-j'],
              ))
              _my_addr = _active['address']
              _my_coord = _active['at'][${coordIdx}]
              _my_ws = _active['workspace']['id']

              _qbs = [
                  c for c in _clients
                  if c['address'] != _my_addr
                  and c['workspace']['id'] == _my_ws
                  and 'qutebrowser' in c.get('class', ''')
              ]

              _candidates = sorted(
                  [c for c in _qbs
                   if c['at'][${coordIdx}] ${if filterLess then "<" else ">"} _my_coord],
                  key=lambda c: c['at'][${coordIdx}],
                  reverse=${sortReverse},
              )
              if not _candidates:
                  _candidates = [
                      c for c in _qbs if c['at'][${coordIdx}] == _my_coord
                  ]

              if _candidates:
                  _best = _candidates[0]
                  _target_title = _best['title']
                  for _qw_id in objreg.window_registry:
                      if _qw_id == _wid:
                          continue
                      _qwin = objreg.window_registry[_qw_id]
                      if _qwin.windowTitle() == _target_title:
                          _r.run('tab-give ' + str(_qw_id))
                          _ttb = objreg.get(
                              'tabbed-browser', scope='window',
                              window=_qw_id,
                          )
                          _ttb.widget.setCurrentIndex(
                              _ttb.widget.count() - 1,
                          )
                          subprocess.check_call(
                              ['hyprctl', 'dispatch', 'focuswindow',
                               'address:' + _best['address']],
                          )
                          _gave = True
                          break
          except Exception:
              pass

          if not _gave:
              _r.run('tab-give')
    '';

  mkMergeScript = workspaceOnly:
    pkgs.writeText "merge-qutebrowsers${if workspaceOnly then "-ws" else ""}.py" ''
      import json
      import subprocess
      from qutebrowser.utils import objreg
      from qutebrowser.commands import runners

      _wid = None
      for _w in objreg.window_registry:
          if objreg.window_registry[_w].isActiveWindow():
              _wid = _w
              break
      if _wid is None:
          _wid = next(iter(objreg.window_registry))

      _r = runners.CommandRunner(_wid)

      try:
          _active = json.loads(subprocess.check_output(
              ['hyprctl', 'activewindow', '-j'],
          ))
          _clients = json.loads(subprocess.check_output(
              ['hyprctl', 'clients', '-j'],
          ))
          _my_addr = _active['address']
          _my_ws = _active['workspace']['id']

          _qbs = [
              c for c in _clients
              if c['address'] != _my_addr
              and 'qutebrowser' in c.get('class', ''')
              ${if workspaceOnly then "and c['workspace']['id'] == _my_ws" else ""}
          ]

          for _c in _qbs:
              _target_title = _c['title']
              for _qw_id in list(objreg.window_registry):
                  if _qw_id == _wid:
                      continue
                  _qwin = objreg.window_registry.get(_qw_id)
                  if _qwin is None:
                      continue
                  if _qwin.windowTitle() == _target_title:
                      _other_r = runners.CommandRunner(_qw_id)
                      _other_tb = objreg.get(
                          'tabbed-browser', scope='window',
                          window=_qw_id,
                      )
                      _cnt = _other_tb.widget.count()
                      for _i in range(_cnt):
                          _other_r.run('tab-give ' + str(_wid))
                      break
      except Exception:
          pass
    '';

  tabMoveLeft  = mkTabMoveScript "left";
  tabMoveRight = mkTabMoveScript "right";
  tabMoveUp    = mkTabMoveScript "up";
  tabMoveDown  = mkTabMoveScript "down";
  mergeWorkspace = mkMergeScript true;
  mergeAll       = mkMergeScript false;
in
{
  config = lib.mkIf config.skynet.module.desktop.qutebrowser.enable {
    xdg.desktopEntries.qutebrowser = {
      name = "qutebrowser";
      exec = "env LIBVA_DRIVER_NAME=iHD qutebrowser %u";
      mimeType = [ "text/html" "x-scheme-handler/http" "x-scheme-handler/https" ];
    };

    xdg.mimeApps.defaultApplications = {
      "x-scheme-handler/http" = "qutebrowser.desktop";
      "x-scheme-handler/https" = "qutebrowser.desktop";
      "text/html" = "qutebrowser.desktop";
    };

    programs.qutebrowser = {
      enable = true;

      searchEngines = {
        DEFAULT = "https://www.google.com/search?q={}";
      };

      settings = {
        url.start_pages = [ "https://news.ycombinator.com" ];
        url.default_page = "https://news.ycombinator.com";
        tabs.last_close = "close";
      };

      extraConfig = ''
        # Nuke normal-mode defaults only — our config.bind() calls live in
        # c.bindings.commands which is a separate layer and unaffected.
        c.bindings.default['normal'] = {}
      '';

      keyBindings = {
        normal = {
          # Essentials
          "<Escape>" = "clear-keychain ;; search ;; fullscreen --leave";
          ":" = "cmd-set-text :";
          "i" = "mode-enter passthrough";
          # Open URL
          "o" = "cmd-set-text -s :open";
          "<F6>" = "cmd-set-text -s :open";
          # Passthrough / undo
          "<Ctrl+Shift+t>" = "undo";
          # New tab / close
          "<Ctrl+t>" = "cmd-set-text -s :open -t";
          "O" = "cmd-set-text -s :open -t";
          "<Ctrl+w>" = "tab-close";
          "<Ctrl+Shift+n>" = "open -p";
          # Tab navigation
          "<Ctrl+Tab>" = "tab-next";
          "<Ctrl+Shift+Tab>" = "tab-prev";
          # History navigation
          "<Ctrl+Left>" = "back";
          "<Ctrl+Right>" = "forward";
          # Search
          "<Ctrl+f>" = "cmd-set-text /";
          "n" = "search-next";
          "N" = "search-prev";
          # DevTools
          "<F12>" = "devtools";
          # Scroll / tab navigation
          "<Alt+Up>"    = "scroll-px 0 -300";
          "<Alt+Down>"  = "scroll-px 0 300";
          "<Alt+Left>"  = "tab-prev";
          "<Alt+Right>" = "tab-next";
          # Tab rearrange / give to nearest qutebrowser
          "<Alt+Shift+Left>"  = "debug-pyeval -q exec(open('${tabMoveLeft}').read())";
          "<Alt+Shift+Right>" = "debug-pyeval -q exec(open('${tabMoveRight}').read())";
          "<Alt+Shift+Up>"    = "debug-pyeval -q exec(open('${tabMoveUp}').read())";
          "<Alt+Shift+Down>"  = "debug-pyeval -q exec(open('${tabMoveDown}').read())";
          # Tab by number (Alt+1..9 → tab 1..9, Alt+0 → tab 10)
          "<Alt+1>" = "tab-focus 1";
          "<Alt+2>" = "tab-focus 2";
          "<Alt+3>" = "tab-focus 3";
          "<Alt+4>" = "tab-focus 4";
          "<Alt+5>" = "tab-focus 5";
          "<Alt+6>" = "tab-focus 6";
          "<Alt+7>" = "tab-focus 7";
          "<Alt+8>" = "tab-focus 8";
          "<Alt+9>" = "tab-focus 9";
          "<Alt+0>" = "tab-focus 10";
          # Yank URL
          "yy" = "yank";
          # Zoom
          "<Ctrl+0>" = "zoom";
          # Reload
          "<Ctrl+r>" = "reload";
          # Merge
          "<Alt+m>"         = "debug-pyeval -q exec(open('${mergeWorkspace}').read())";
          "<Alt+Shift+m>"   = "debug-pyeval -q exec(open('${mergeAll}').read())";
        };
        passthrough = {
          "<Escape>" = "mode-leave";
          "<Shift+Escape>" = "fake-key <Escape>";
          "<Ctrl+t>" = "cmd-set-text -s :open -t";
          "<Ctrl+f>" = "cmd-set-text /";
          "<Ctrl+Tab>" = "tab-next";
          "<Ctrl+Shift+Tab>" = "tab-prev";
        };
      };
    };
  };
}
