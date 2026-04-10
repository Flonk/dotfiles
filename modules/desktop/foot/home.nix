{
  pkgs,
  config,
  lib,
  ...
}:
{
  config = lib.mkIf config.skynet.module.desktop.foot.enable {
    programs.foot = {
      enable = true;

      settings = {
        main = {
          # shell=$SHELL (if set, otherwise user's default shell from /etc/passwd)
          # term=foot (or xterm-256color if built with -Dterminfo=disabled)
          login-shell = "no";
          # app-id=foot
          # title=foot
          locked-title = "no";
          # font=monospace:size=8
          # font-bold=<bold variant of regular font>
          # font-italic=<italic variant of regular font>
          # font-bold-italic=<bold+italic variant of regular font>
          # font-size-adjustment=0.5
          # line-height=<font metrics>
          letter-spacing = "0";
          # horizontal-letter-offset=0
          # vertical-letter-offset=0
          # underline-offset=<font metrics>
          # underline-thickness=<font underline thickness>
          # strikeout-thickness=<font strikeout thickness>
          # box-drawings-uses-font-glyphs=no
          dpi-aware = "no";
          # gamma-correct-blending=no
          # initial-color-theme=1
          initial-window-size-pixels = "700x500";
          # initial-window-size-chars=<COLSxROWS>
          initial-window-mode = "windowed";
          # pad=0x0 center-when-maximized-and-fullscreen
          resize-by-cells = "yes";
          # resize-keep-grid=yes
          # resize-delay-ms=100
          # bold-text-in-bright=no
          word-delimiters = ",│`|:\"'()[]{}<>";
          # selection-target=primary
          # workers=<number of logical CPUs>
          # utmp-helper=/usr/lib/utempter/utempter
          # uppercase-regex-insert=yes
        };

        bell = {
          # urgent=no
          # notify=no
          # visual=no
          # command=
          # command-focused=no
        };

        desktop-notifications = {
          # command=notify-send --wait --app-name ${app-id} --icon ${app-id} --category ${category} --urgency ${urgency} --expire-time ${expire-time} --hint STRING:image-path:${icon} --hint BOOLEAN:suppress-sound:${muted} --hint STRING:sound-name:${sound-name} --replace-id ${replace-id} ${action-argument} --print-id -- ${title} ${body}
          # command-action-argument=--action ${action-name}=${action-label}
          # close=""
          # inhibit-when-focused=yes
        };

        scrollback = {
          lines = "1000";
          # multiplier=3.0
          # indicator-position=relative
          # indicator-format=""
        };

        url = {
          # launch=xdg-open ${url}
          # label-letters=sadfjklewcmpgh
          # osc8-underline=url-mode
          # protocols=http, https, ftp, ftps, file, gemini, gopher, irc, ircs
          # uri-characters=abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.,~:;/?#@!$&%*+="'()[]
        };

        cursor = {
          # style=block
          # blink=no
          # blink-rate=500
          # beam-thickness=1.5
          # underline-thickness=<font underline thickness>
        };

        mouse = {
          # hide-when-typing=no
          # alternate-scroll-mode=yes
        };

        "colors-dark" = {
          # alpha=1.0
          # alpha-mode=default
          # foreground=ffffff
          # flash=7f7f00
          # flash-alpha=0.5
          # cursor=<inverse foreground/background>
        };

        csd = {
          # preferred=server
          # size=26
          # font=<primary font>
          # color=<foreground color>
          # hide-when-maximized=no
          # double-click-to-maximize=yes
          # border-width=0
          # border-color=<csd.color>
          # button-width=26
          # button-color=<background color>
          # button-minimize-color=<regular4>
          # button-maximize-color=<regular2>
          # button-close-color=<regular1>
        };

        key-bindings = {
          # scrollback-up-page=Shift+Page_Up Shift+KP_Page_Up
          # scrollback-up-half-page=none
          # scrollback-up-line=none
          # scrollback-down-page=Shift+Page_Down Shift+KP_Page_Down
          # scrollback-down-half-page=none
          # scrollback-down-line=none
          # scrollback-home=none
          # scrollback-end=none
          # clipboard-copy=Control+Shift+c XF86Copy
          # clipboard-paste=Control+Shift+v XF86Paste
          # primary-paste=Shift+Insert
          # search-start=Control+Shift+r
          # font-increase=Control+plus Control+equal Control+KP_Add
          # font-decrease=Control+minus Control+KP_Subtract
          # font-reset=Control+0 Control+KP_0
          # spawn-terminal=Control+Shift+n
          # minimize=none
          # maximize=none
          # fullscreen=none
          # pipe-visible=[sh -c "xurls | fuzzel | xargs -r firefox"] none
          # pipe-scrollback=[sh -c "xurls | fuzzel | xargs -r firefox"] none
          # pipe-selected=[xargs -r firefox] none
          # pipe-command-output=[wl-copy] none
          # show-urls-launch=Control+Shift+o
          # show-urls-copy=none
          # show-urls-persistent=none
          # prompt-prev=Control+Shift+z
          # prompt-next=Control+Shift+x
          # unicode-input=Control+Shift+u
          # color-theme-switch-1=none
          # color-theme-switch-2=none
          # color-theme-toggle=none
          # noop=none
          # quit=none
        };

        search-bindings = {
          # cancel=Control+g Control+c Escape
          # commit=Return KP_Enter
          # find-prev=Control+r
          # find-next=Control+s
          # cursor-left=Left Control+b
          # cursor-left-word=Control+Left Mod1+b
          # cursor-right=Right Control+f
          # cursor-right-word=Control+Right Mod1+f
          # cursor-home=Home Control+a
          # cursor-end=End Control+e
          # delete-prev=BackSpace
          # delete-prev-word=Mod1+BackSpace Control+BackSpace
          # delete-next=Delete
          # delete-next-word=Mod1+d Control+Delete
          # delete-to-start=Control+u
          # delete-to-end=Control+k
          # extend-char=Shift+Right
          # extend-to-word-boundary=Control+w Control+Shift+Right
          # extend-to-next-whitespace=Control+Shift+w
          # extend-line-down=Shift+Down
          # extend-backward-char=Shift+Left
          # extend-backward-to-word-boundary=Control+Shift+Left
          # extend-backward-to-next-whitespace=none
          # extend-line-up=Shift+Up
          # clipboard-paste=Control+v Control+Shift+v Control+y XF86Paste
          # primary-paste=Shift+Insert
          # unicode-input=none
          # scrollback-up-page=Shift+Page_Up Shift+KP_Page_Up
          # scrollback-up-half-page=none
          # scrollback-up-line=none
          # scrollback-down-page=Shift+Page_Down Shift+KP_Page_Down
          # scrollback-down-half-page=none
          # scrollback-down-line=none
          # scrollback-home=none
          # scrollback-end=none
        };

        url-bindings = {
          # cancel=Control+g Control+c Control+d Escape
          # toggle-url-visible=t
        };

        mouse-bindings = {
          # scrollback-up-mouse=BTN_WHEEL_BACK
          # scrollback-down-mouse=BTN_WHEEL_FORWARD
          # font-increase=Control+BTN_WHEEL_BACK
          # font-decrease=Control+BTN_WHEEL_FORWARD
          # selection-override-modifiers=Shift
          # primary-paste=BTN_MIDDLE
          # select-begin=BTN_LEFT
          # select-begin-block=Control+BTN_LEFT
          # select-extend=BTN_RIGHT
          # select-extend-character-wise=Control+BTN_RIGHT
          # select-word=BTN_LEFT-2
          # select-word-whitespace=Control+BTN_LEFT-2
          # select-quote=BTN_LEFT-3
          # select-row=BTN_LEFT-4
        };
      };
    };

    xdg.desktopEntries.foot = {
      name = "Foot Terminal";
      genericName = "Terminal";
      comment = "Fast, lightweight and minimalistic Wayland terminal emulator";
      exec = "foot";
      icon = "foot";
      terminal = false;
      type = "Application";
      categories = [
        "System"
        "TerminalEmulator"
      ];
    };
  };
}
