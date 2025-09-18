{
  pkgs,
  config,
  lib,
  ...
}:
let
  # Convert #rrggbb -> 0xrrggbb
  hexTo0x = s: "0x${builtins.replaceStrings [ "#" ] [ "" ] s}";
  c = config.theme.color;
  # bg removed per user request; keep a secondary shade for borders as foreground
  bg2 = hexTo0x c.app200;
  fg = hexTo0x c.text;
  accent = hexTo0x c.wm800;
  muted = hexTo0x c.app400;
in
{

  home.packages = with pkgs; [
    nchat
  ];

  xdg.configFile."nchat/color.conf".text = ''
    default_color_bg=
    default_color_fg=${fg}
    dialog_attr=
    dialog_attr_selected=reverse
    dialog_color_bg=
    dialog_color_fg=${fg}
    entry_attr=
    entry_color_bg=
    entry_color_fg=${fg}
    help_attr=reverse
    help_color_bg=
    help_color_fg=${fg}
    history_name_attr=bold
    history_name_attr_selected=reverse
    history_name_recv_color_bg=
    history_name_recv_color_fg=${fg}
    history_name_recv_group_color_bg=
    history_name_recv_group_color_fg=${fg}
    history_name_sent_color_bg=
    history_name_sent_color_fg=${muted}
    history_text_attachment_color_bg=
    history_text_attachment_color_fg=${muted}
    history_text_attr=
    history_text_attr_selected=reverse
    history_text_quoted_color_bg=
    history_text_quoted_color_fg=${muted}
    history_text_reaction_color_bg=
    history_text_reaction_color_fg=${muted}
    history_text_recv_color_bg=
    history_text_recv_color_fg=${fg}
    history_text_recv_group_color_bg=
    history_text_recv_group_color_fg=${fg}
    history_text_sent_color_bg=
    history_text_sent_color_fg=${muted}
    list_attr=
    list_attr_selected=reverse
    list_color_bg=
    list_color_fg=${fg}
    list_color_unread_bg=
    list_color_unread_fg=${accent}
    listborder_attr=
    listborder_color_bg=
    listborder_color_fg=${bg2}
    status_attr=reverse
    status_color_bg=
    status_color_fg=${fg}
    top_attr=reverse
    top_color_bg=
    top_color_fg=${fg}
  '';

}
