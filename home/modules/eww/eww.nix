{
  pkgs,
  config,
  lib,
  ...
}:
let
  # -------------------- Yuck pieces --------------------
  yuckHeader = ''
    ;; Variables
    (defpoll clock_time :interval "5m" "date +\%I")
    (defpoll clock_minute :interval "5s" "date +\%M")
    (defpoll clock_date :interval "10h" "date '+%d/%m'")
    (defpoll volume_percent :interval "3s" "amixer -D pulse sget Master | grep 'Left:' | awk -F'[][]' '{ print $2 }' | tr -d '%'")
    (defpoll mic_percent :interval "3s" "amixer -D pulse sget Capture | grep 'Left:' | awk -F'[][]' '{ print $2 }' | tr -d '%'")
    (defpoll brightness_percent :interval "5s" "brightnessctl -m -d intel_backlight | awk -F, '{print substr($4, 0, length($4)-1)}' | tr -d '%'")
    (defpoll battery :interval "15s" "./scripts/battery --bat")
    (defpoll battery_status :interval "1m" "./scripts/battery --bat-st")
    (defpoll memory :interval "15s" "scripts/memory")
    (defpoll memory_used_mb :interval "2m" "scripts/mem-ad used")
    (defpoll memory_total_mb :interval "2m" "scripts/mem-ad total")
    (defpoll memory_free_mb :interval "2m" "scripts/mem-ad free")
    (defvar vol_reveal false)
    (defvar br_reveal false)
    (defvar music_reveal false)
    (defvar wifi_rev false)
    (defvar time_rev false)
    (deflisten workspace "scripts/workspace")

    (defvar eww "$HOME/.local/bin/eww/eww -c $HOME/.config/eww/bar")

    (defpoll COL_WLAN :interval "1m" "~/.config/eww/bar/scripts/wifi --COL")
    (defpoll ESSID_WLAN :interval "1m" "~/.config/eww/bar/scripts/wifi --ESSID")
    (defpoll WLAN_ICON :interval "1m" "~/.config/eww/bar/scripts/wifi --ICON")

    (defpoll song :interval "2s"  "~/.config/eww/bar/scripts/music_info --song")
    (defpoll song_artist :interval "2s"  "~/.config/eww/bar/scripts/music_info --artist")
    (defpoll current_status :interval "1s"  "~/.config/eww/bar/scripts/music_info --time")
    (defpoll song_status :interval "2s"  "~/.config/eww/bar/scripts/music_info --status")
    (defpoll cover_art :interval "2s"  "~/.config/eww/bar/scripts/music_info --cover")

    (defpoll calendar_day :interval "20h" "date '+%d'")
    (defpoll calendar_year :interval "20h" "date '+%Y'")
  '';

  yuckWifi = ''
    (defwidget wifi []
      (eventbox :onhover "''${eww} update wifi_rev=true"
                :onhoverlost "''${eww} update wifi_rev=false"
        (box :vexpand "false" :hexpand "false" :space-evenly "false"
          (button :class "module-wif" :onclick "networkmanager_dmenu" :wrap "false" :limit-width 12 :style "color: ''${COL_WLAN};" WLAN_ICON)
          (revealer :transition "slideright" :reveal wifi_rev :duration "350ms"
            (label :class "module_essid" :text ESSID_WLAN :orientation "h")))))
  '';

  yuckWorkspaces = ''
    (defwidget workspaces []
      (literal :content workspace))
  '';

  yuckBat = ''
    (defwidget bat []
      (box :class "bat_module" :vexpand "false" :hexpand "false"
        (circular-progress :value battery :class "batbar" :thickness 4
          (button :class "iconbat" :limit-width 2 :tooltip "battery on ''${battery}%" :show_truncated false :onclick "$HOME/.config/eww/bar/scripts/pop system" :wrap false ""))))
  '';

  yuckMem = ''
    (defwidget mem []
      (box :class "mem_module" :vexpand "false" :hexpand "false"
        (circular-progress :value memory :class "membar" :thickness 4
          (button :class "iconmem" :limit-width 2 :tooltip "using ''${memory}% ram" :onclick "$HOME/.config/eww/bar/scripts/pop system" :show_truncated false :wrap false ""))))
  '';

  yuckSep = ''
    (defwidget sep []
      (box :class "module-2" :vexpand "false" :hexpand "false"
        (label :class "separ" :text "|")))
  '';

  yuckClock = ''
    (defwidget clock_module []
      (eventbox :onhover "''${eww} update time_rev=true" :onhoverlost "''${eww} update time_rev=false"
        (box :class "module" :space-evenly "false" :orientation "h" :spacing "3"
          (label :text clock_time :class "clock_time_class")
          (label :text "" :class "clock_time_sep")
          (label :text clock_minute :class "clock_minute_class")
          (revealer :transition "slideleft" :reveal time_rev :duration "350ms"
            (button :class "clock_date_class" :onclick "$HOME/.config/eww/bar/scripts/pop calendar" clock_date)))))
  '';

  yuckVolume = ''
    (defwidget volume []
      (eventbox :onhover "''${eww} update vol_reveal=true" :onhoverlost "''${eww} update vol_reveal=false"
        (box :class "module-2" :space-evenly "false" :orientation "h" :spacing "3"
          (button :onclick "scripts/pop audio" :class "volume_icon" "")
          (revealer :transition "slideleft" :reveal vol_reveal :duration "350ms"
            (scale :class "volbar" :value volume_percent :orientation "h" :tooltip "''${volume_percent}%" :max 100 :min 0 :onchange "amixer -D pulse sset Master {}%")))))
  '';

  yuckBright = ''
    (defwidget bright []
      (eventbox :onhover "''${eww} update br_reveal=true" :onhoverlost "''${eww} update br_reveal=false"
        (box :class "module-2" :space-evenly "false" :orientation "h" :spacing "3"
          (label :text "" :class "bright_icon" :tooltip "brightness")
          (revealer :transition "slideleft" :reveal br_reveal :duration "350ms"
            (scale :class "brightbar" :value brightness_percent :orientation "h" :tooltip "''${brightness_percent}%" :max 100 :min 0 :onchange "brightnessctl set {}%")))))
  '';

  yuckMusic = ''
    (defwidget music []
      (eventbox :onhover "''${eww} update music_reveal=true" :onhoverlost "''${eww} update music_reveal=false"
        (box :class "module-2" :orientation "h" :space-evenly "false" :vexpand "false" :hexpand "false"
          (box :class "song_cover_art" :vexpand "false" :hexpand "false" :style "background-image: url(' ''${cover_art}');")
          (button :class "song" :wrap "true" :onclick "~/.config/eww/bar/scripts/pop music" song)
          (revealer :transition "slideright" :reveal music_reveal :duration "350ms"
            (box :vexpand "false" :hexpand "false" :oreintation "h"
              (button :class "song_btn_prev" :onclick "~/.config/eww/bar/scripts/music_info --prev" "")
              (button :class "song_btn_play" :onclick "~/.config/eww/bar/scripts/music_info --toggle" song_status)
              (button :class "song_btn_next" :onclick "~/.config/eww/bar/scripts/music_info --next" ""))))))
  '';

  yuckLeft = ''
    (defwidget left []
      (box :orientation "h" :space-evenly false :halign "end" :class "left_modules"
        (bright)
        (volume)
        (wifi)
        (sep)
        (bat)
        (mem)
        (sep)
        (clock_module)))
  '';

  yuckRight = ''
    (defwidget right []
      (box :orientation "h" :space-evenly false :halign "start" :class "right_modules"
        (workspaces)))
  '';

  yuckCenter = ''
    (defwidget center []
      (box :orientation "h" :space-evenly false :halign "center" :class "center_modules"
        (music)))
  '';

  yuckBar = ''
    (defwidget bar_1 []
      (box :class "bar_class" :orientation "h" (right) (center) (left)))
  '';

  yuckSystemWidget = ''
    (defwidget system []
      (box :class "sys_win" :orientation "v" :space-evenly "false" :hexpand "false" :vexpand "false" :spacing 0
        (box :class "sys_bat_box" :orientation "h" :space-evenly "false"
          (circular-progress :value battery :class "sys_bat" :thickness 9
            (label :text "" :class "sys_icon_bat" :limit-width 2 :show_truncated false :wrap false))
          (box :orientation "v" :space-evenly "false" :spacing 0 :hexpand "false" :vexpand "false"
            (label :text "battery" :halign "start" :class "sys_text_bat" :limit-width 9 :show_truncated false :wrap false)
            (label :text "''${battery}%" :halign "start" :class "sys_text_bat_sub" :limit-width 22 :show_truncated false :wrap false)
            (label :text "''${battery_status}" :halign "start" :class "sys_text_bat_sub" :limit-width 22 :show_truncated false :wrap false)))
        (label :text "" :class "sys_sep" :halign "center")
        (box :class "sys_mem_box" :orientation "h" :space-evenly "false" :halign "start"
          (circular-progress :value memory :class "sys_mem" :thickness 9
            (label :text "" :class "sys_icon_mem" :limit-width 2 :show_truncated false :wrap false :angle 0.0))
          (box :orientation "v" :space-evenly "false" :spacing 0 :hexpand "false" :vexpand "false"
            (label :text "memory" :halign "start" :class "sys_text_mem" :limit-width 9 :show_truncated false :wrap false)
            (label :text "''${memory_used_mb} | ''${memory_total_mb}mb " :halign "start" :class "sys_text_mem_sub" :limit-width 22 :show_truncated false :wrap false)
            (label :text "''${memory_free_mb}mb free" :halign "start" :class "sys_text_mem_sub" :limit-width 22 :show_truncated false :wrap false)))))
  '';

  yuckCalWidget = ''
    (defwidget cal []
      (box :class "cal" :orientation "v"
        (box :class "cal-in"
          (calendar :class "cal" :day calendar_day :year calendar_year))))
  '';

  yuckAudioWidget = ''
    (defwidget audio []
      (box :class "audio-box" :orientation "v" :space-evenly "false" :vexpand "false" :hexpand "false"
        (box :halign "v" :space-evenly "false" :hexpand "false" :vexpand "false"
          (box :class "speaker_icon" :orientation "v")
          (box :orientation "v" :halign "center" :vexpand "false" :hexpand "false"
            (label :class "speaker_text" :text "speaker" :valign "center" :halign "left")
            (box :class "speaker_bar" :halign "center" :vexpand "false" :hexpand "false"
              (scale :value volume_percent :space-evenly "false" :orientation "h" :onchange "amixer -D pulse sset Master {}%" :tooltip "volume on ''${volume_percent}%" :max 100 :min 0))))
        (label :text "" :class "audio_sep" :halign "center")
        (box :halign "v" :space-evenly "false" :hexpand "false" :vexpand "false"
          (box :class "mic_icon" :orientation "v")
          (box :orientation "v" :halign "center" :vexpand "false" :hexpand "false"
            (label :class "mic_text" :text "mic" :valign "center" :halign "left")
            (box :class "mic_bar" :halign "center" :vexpand "false" :hexpand "false"
              (scale :value mic_percent :space-evenly "false" :orientation "h" :tooltip "mic on ''${mic_percent}%" :onchange "amixer -D pulse sset Capture {}%" :max 100 :min 0))))))
  '';

  yuckMusicPopWidget = ''
    (defwidget music_pop []
      (box :class "music_pop" :orientation "h" :space-evenly "false" :vexpand "false" :hexpand "false"
        (box :class "music_cover_art" :vexpand "false" :hexpand "false" :style "background-image: url(' ''${cover_art}');")
        (box :orientation "v" :spacing 20 :space-evenly "false" :vexpand "false" :hexpand "false"
          (label :halign "center" :class "music" :wrap "true" :limit-width 13 :text song)
          (label :halign "center" :class "music_artist" :wrap "true" :limit-width 15 :text song_artist)
          (box :orientation "h" :spacing 15 :halign "center" :space-evenly "false" :vexpand "false" :hexpand "false"
            (button :class "music_btn_prev" :onclick "~/.config/eww/bar/scripts/music_info --prev" "")
            (button :class "music_btn_play" :onclick "~/.config/eww/bar/scripts/music_info --toggle" song_status)
            (button :class "music_btn_next" :onclick "~/.config/eww/bar/scripts/music_info --next" ""))
          (box :class "music_bar" :halign "center" :vexpand "false" :hexpand "false" :space-evenly "false"
            (scale :onscroll "mpc -q seek {}" :min 0 :active "true" :max 100 :value current_status))))
  '';

  yuckWindows = ''
    (defwindow bar
      :geometry (geometry :x "0%" :y "9px" :width "98%" :height "30px" :anchor "top center")
      :stacking "fg" :windowtype "dock" :monitor "eDP-1"
      (bar_1))

    (defwindow calendar :geometry (geometry :x "-20px" :y "7%" :anchor "top right" :width "270px" :height "60px") (cal))

    (defwindow audio_ctl :geometry (geometry :x "-20px" :y "7%" :anchor "top right" :width "280px" :height "60px") (audio))

    (defwindow system :geometry (geometry :x "-20px" :y "7%" :anchor "top right" :width "290px" :height "120px") (system))

    (defwindow music_win :stacking "fg" :focusable "false" :screen 1
      :geometry (geometry :x "0" :y "7%" :width 428 :height 104 :anchor "top center")
      (music_pop))
  '';

  yuckAll = lib.concatStrings [
    yuckHeader
    yuckWifi
    yuckWorkspaces
    yuckBat
    yuckMem
    yuckSep
    yuckClock
    yuckVolume
    yuckBright
    yuckMusic
    yuckLeft
    yuckRight
    yuckCenter
    yuckBar
    yuckSystemWidget
    yuckCalWidget
    yuckAudioWidget
    yuckMusicPopWidget
    yuckWindows
  ];

  # -------------------- SCSS pieces --------------------
  scssBase = ''
    /** EWW.SCSS\n    Created by saimoom **/
    *{ all: unset; font-family: feather; font-family: DaddyTimeMono NF; }

    /** tooltip!! **/
    tooltip.background { background-color: #0f0f17; font-size: 18; border-radius: 10px; color: #bfc9db; }
    tooltip label { margin: 6px; }

    /** General **/
    .module { margin: 0px 0px 0px 0px; border-radius: 10px 16px 0px 10px; }
  '';

  scssBar = ''
    .bar_class { background-color: #0f0f17; border-radius: 16px; }
  '';

  scssWifi = ''
    .module_essid { font-size: 18; color: #a1bdce; margin: 0px 10px 0px 0px; }
    .module-wif { font-size: 22; color: #a1bdce; border-radius: 100%; margin: 0px 10px 0px 5px; }
  '';

  scssClock = ''
    .clock_time_sep { font-size: 16; color: #bfc9db; margin: 0px 4px 1px 4px; }
    .clock_time_class, .clock_minute_class { font-size: 23; }
    .clock_date_class { font-size: 18; margin: 0px 20px 0px -1px; color: #d7beda; }
    .clock_minute_class { margin: 0px 20px 0px 3px; color: #bfc9db; }
    .clock_time_class { color: #bfc9db; font-weight: bold; margin: 0px 5px 0px 0px; }
  '';

  scssMem = ''
    .membar { color: #e0b089; background-color: #38384d; border-radius: 10px; }
    .mem_module { background-color: #0f0f17; border-radius: 16px; margin: 0px 10px 0px 3px; }
    .iconmem { color: #e0b089; font-size: 15; margin: 10px; }
  '';

  scssBat = ''
    .batbar { color: #afbea2; background-color: #38384d; border-radius: 10px; }
    .bat_module { background-color: #0f0f17; border-radius: 16px; margin: 0px 10px 0px 10px; }
    .iconbat { color: #afbea2; font-size: 15; margin: 10px; }
  '';

  scssBright = ''
    .brightbar trough highlight { background-image: linear-gradient(to right, #e4c9af 30%, #f2cdcd 50%, #e0b089 100% *50); border-radius: 10px; }
    .bright_icon { font-size: 22; color: #e4c9af; margin: 0px 10px 0px 10px; }
  '';

  scssVolume = ''
    .volbar trough highlight { background-image: linear-gradient(to right, #afcee0 30%, #a1bdce 50%, #77a5bf 100% *50); border-radius: 10px; }
    .volume_icon { font-size: 22; color: #a1bdce; margin: 0px 10px 0px 10px; }
  '';

  scssSep = ''
    .separ { color: #3e424f; font-weight: bold; font-size: 22px; margin: 0px 8px 0px 8px; }
  '';

  scssScales = ''
    scale trough { all: unset; background-color: #22242b; box-shadow: 0 2px 3px 2px #06060b; border-radius: 16px; min-height: 10px; min-width: 70px; margin: 0px 10px 0px 0px; }
  '';

  scssWorkspaces = ''
    .works { font-size: 27px; font-weight: normal; margin: 5px 0px 0px 20px; background-color: #0f0f17; }
    .0 , .01, .02, .03, .04, .05, .06,
    .011, .022, .033, .044, .055, .066 { margin: 0px 10px 0px 0px; }
    .0 { color: #3e424f; }
    .01, .02, .03, .04, .05, .06 { color: #bfc9db; }
    .011, .022, .033, .044, .055, .066 { color: #a1bdce; }
  '';

  scssMusicInline = ''
    .song_cover_art { background-size: cover; background-position: center; min-height: 24px; min-width: 24px; margin: 10px; border-radius: 100px; }
    .song { color: #a1bdce; font-size: 18px; font-weight: bold; margin: 3px 5px 0px 0px; }
    .song_btn_play { color: #a1bdce; font-size: 28px; margin: 3px 0px 0px 5px; }
    .song_btn_prev, .song_btn_next { color: #bfc9db; font-size: 24px; margin: 3px 0px 0px 5px; }
  '';

  scssCalendar = ''
    .cal { background-color: #0f0f17; font-family: JetBrainsMono Nerd Font; font-size: 18px; font-weight: normal; }
    .cal-in { padding: 0px 10px 0px 10px; color: #bfc9db; }
    .cal .cal.highlight { padding: 20px; }
    .cal .cal { padding: 5px 5px 5px 5px; margin-left: 10px; }
    calender { color: #bfc9db; }
    calendar:selected { color: #a1bdce; }
    calendar.header { color: #a1bdce; font-weight: bold; }
    calendar.button { color: #afbea2; }
    calendar.highlight { color: #a1bdce; font-weight: bold; }
    calendar:indeterminate { color: #bfc9db; }
  '';

  scssSystem = ''
    .sys_sep { color: #38384d; font-size: 18; margin: 0px 10px 0px 10px; }
    .sys_text_bat_sub, .sys_text_mem_sub { font-size: 16; color: #bbc5d7; margin: 5px 0px 0px 25px; }
    .sys_text_bat, .sys_text_mem { font-size: 21; font-weight: bold; margin: 14px 0px 0px 25px; }
    .sys_icon_bat, .sys_icon_mem { font-size: 30; margin: 30px; }
    .sys_win { background-color: #0f0f17; }
    .sys_bat { color: #afbea2; background-color: #38384d; border-radius: 10px; }
    .sys_mem { color: #e4c9af; background-color: #38384d; border-radius: 10px; }
    .sys_icon_bat, .sys_text_bat { color: #afbea2; }
    .sys_icon_mem, .sys_text_mem { color: #e4c9af; }
    .sys_bat_box { border-radius: 16px; margin: 15px 10px 10px 20px; }
    .sys_mem_box { border-radius: 16px; margin: 10px 10px 15px 20px; }
  '';

  scssMusicPop = ''
    .music_pop { background-color: #0f0f17; border-radius: 16px; }
    .music_cover_art { background-size: cover; background-position: center; min-height: 100px; box-shadow: 5px 5px 5px 5px #06060b; min-width: 170px; margin: 20px; border-radius: 20px; }
    .music { color: #a1bdce; font-size: 20px; font-weight: bold; margin: 20px 0px 0px -15px; }
    .music_artist { color: #bbc5d7; font-size: 16px; font-weight: normal; margin: 0px 0px 0px 0px; }
    .music_btn_prev, .music_btn_play, .music_btn_next { font-family: Iosevka Nerd Font; }
    .music_btn_prev { color: #bbc5d7; font-size: 32px; font-weight: normal; margin: 0px 0px 0px 0px; }
    .music_btn_play { color: #a1bdce; font-size: 48px; font-weight: normal; margin: 0px 0px 0px 0px; }
    .music_btn_next { color: #bbc5d7; font-size: 32px; font-weight: normal; margin: 0px 0px 0px 0px; }
    .music_bar scale trough highlight { all: unset; background-image: linear-gradient(to right, #afcee0 30%, #a1bdce 50%, #77a5bf 100% *50); border-radius: 24px; }
    .music_bar scale trough { all: unset; background-color: #232232; box-shadow: 0 6px 5px 2px #06060b; border-radius: 24px; min-height: 13px; min-width: 190px; margin: -10px 10px 20px 0px; }
  '';

  scssAudio = ''
    .audio-box { background-color: #0f0f17; border-radius: 16px; }
    .speaker_icon { background-size: cover; background-image: url('images/speaker.png'); background-position: center; min-height: 70px; min-width: 75px; margin: 10px 20px 5px 20px; border-radius: 12px; }
    .speaker_text { color: #a1bdce; font-size: 26px; font-weight: bold; margin: 20px 0px 0px 0px; }
    .speaker_bar scale trough highlight { all: unset; background-image: linear-gradient(to right, #afcee0 30%, #a1bdce 50%, #77a5bf 100% *50); border-radius: 24px; }
    .speaker_bar scale trough { all: unset; background-color: #232232; box-shadow: 0 6px 5px 2px #06060b; border-radius: 24px; min-height: 13px; min-width: 120px; margin: 0px 0px 5px 0px; }
    .mic_icon { background-size: cover; background-image: url('images/mic.png'); background-position: center; min-height: 70px; min-width: 75px; margin: 5px 20px 20px 20px; border-radius: 12px; }
    .mic_text { color: #a1bdce; font-size: 26px; font-weight: bold; margin: 0px 0px 0px 0px; }
    .mic_bar scale trough highlight { all: unset; background-image: linear-gradient(to right, #afcee0 30%, #a1bdce 50%, #77a5bf 100% *50); border-radius: 24px; }
    .mic_bar scale trough { all: unset; box-shadow: 0 6px 5px 2px #06060b; background-color: #232232; border-radius: 24px; min-height: 13px; min-width: 120px; margin: 0px 0px 20px 0px; }
    .audio_sep { color: #38384d; font-size: 18; margin: 0px 0px 0px 0px; }
  '';

  scssAll = lib.concatStrings [
    scssBase
    scssBar
    scssWifi
    scssClock
    scssMem
    scssBat
    scssBright
    scssVolume
    scssSep
    scssScales
    scssWorkspaces
    scssMusicInline
    scssCalendar
    scssSystem
    scssMusicPop
    scssAudio
  ];
in
{
  xdg.configFile."eww/eww.yuck".text = yuckAll;
  xdg.configFile."eww/eww.scss".text = scssAll;

  systemd.user.services.eww-daemon = {
    Unit = {
      Description = "Eww daemon";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.eww-wayland}/bin/eww daemon";
      Restart = "on-failure";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  systemd.user.services.eww-bar = {
    Unit = {
      Description = "Open Eww bar";
      After = [ "eww-daemon.service" ];
      Requires = [ "eww-daemon.service" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.eww-wayland}/bin/eww open bar";
      ExecStop = "${pkgs.eww-wayland}/bin/eww close bar";
      RemainAfterExit = true;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
