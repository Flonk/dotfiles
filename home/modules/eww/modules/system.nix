{ }:
{
  yuck = ''
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

    (defwindow system :geometry (geometry :x "-20px" :y "7%" :anchor "top right" :width "290px" :height "120px") (system))
  '';

  scss = ''
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
}
