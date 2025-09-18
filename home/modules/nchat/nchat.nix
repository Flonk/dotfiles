{
  pkgs,
  config,
  lib,
  ...
}:
let
  hexTo0x = s: "0x${builtins.replaceStrings [ "#" ] [ "" ] s}";

  bg2 = hexTo0x config.theme.color.app200;
  fg = hexTo0x config.theme.color.text;
  accent = hexTo0x config.theme.color.wm800;
  muted = hexTo0x config.theme.color.app400;
  recvBold = hexTo0x config.theme.color.wm800;
  revcAccent = hexTo0x config.theme.color.wm900;
  recv = hexTo0x config.theme.color.text;
  recvBg = hexTo0x config.theme.color.wm200;
  meBold = hexTo0x config.theme.color.app800;
  me = hexTo0x config.theme.color.text;
  meBg = hexTo0x config.theme.color.app200;
in
{

  home.packages = with pkgs; [
    nchat
  ];

  xdg.configFile."nchat/nchat.conf".text = ''
    attachment_indicator=📎
    attachment_open_command=
    away_status_indication=0
    call_command=
    chat_picker_sorted_alphabetically=0
    confirm_deletion=1
    desktop_notify_active=0
    desktop_notify_command=
    desktop_notify_inactive=0
    downloadable_indicator=+
    emoji_enabled=1
    entry_height=4
    failed_indicator=✗
    file_picker_command=
    file_picker_persist_dir=1
    help_enabled=1
    home_fetch_all=0
    linefeed_on_enter=1
    link_open_command=
    list_enabled=1
    list_width=24
    listdialog_show_filter=1
    mark_read_on_view=1
    mark_read_when_inactive=0
    message_edit_command=
    message_open_command=
    muted_indicate_unread=1
    muted_notify_unread=0
    muted_position_by_timestamp=1
    online_status_dynamic=1
    online_status_share=1
    phone_number_indicator=
    proxy_indicator=🔒
    reactions_enabled=1
    read_indicator=✓
    spell_check_command=
    status_broadcast=1
    syncing_indicator=⇄
    terminal_bell_active=0
    terminal_bell_inactive=0
    terminal_title=
    top_enabled=0
    top_show_version=0
    transfer_send_caption=1
    typing_status_share=1
    unread_indicator=*
  '';

  xdg.configFile."nchat/usercolor.conf".text = ''
    0x6272a4
    0x8be9fd
    0x50fa7b
    0xffb86c
    0xbd93f9
    0xff5555
    0xf1fa8c
  '';

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
    help_attr=
    help_color_bg=${bg2}
    help_color_fg=${hexTo0x config.theme.color.app600}
    history_name_attr=bold
    history_name_attr_selected=reverse
    history_name_recv_color_bg=
    history_name_recv_color_fg=${recvBold}
    history_name_recv_group_color_bg=
    history_name_recv_group_color_fg=usercolor
    history_name_sent_color_bg=
    history_name_sent_color_fg=${meBold}
    history_text_attachment_color_bg=
    history_text_attachment_color_fg=${revcAccent}
    history_text_attr=
    history_text_attr_selected=reverse
    history_text_quoted_color_bg=
    history_text_quoted_color_fg=${revcAccent}
    history_text_reaction_color_bg=
    history_text_reaction_color_fg=${revcAccent}
    history_text_recv_color_bg=
    history_text_recv_color_fg=${recv}
    history_text_recv_group_color_bg=
    history_text_recv_group_color_fg=${fg}
    history_text_sent_color_bg=
    history_text_sent_color_fg=${me}
    list_attr=
    list_attr_selected=reverse
    list_color_bg=
    list_color_fg=${hexTo0x config.theme.color.app500}
    list_color_unread_bg=
    list_color_unread_fg=${accent}
    listborder_attr=
    listborder_color_bg=
    listborder_color_fg=${bg2}
    status_attr=
    status_color_bg=${bg2}
    status_color_fg=${hexTo0x config.theme.color.app600}
    top_attr=
    top_color_bg=${bg2}
    top_color_fg=${hexTo0x config.theme.color.app600}
  '';

  xdg.configFile."nchat/key.conf".text = ''
    backspace=KEY_BACKSPACE
    backspace_alt=KEY_ALT_BACKSPACE
    backward_kill_word=\33\177
    backward_word=
    begin_line=KEY_CTRLA
    cancel=KEY_CTRLC
    clear=KEY_CTRLC
    copy=\33\143
    cut=\33\170
    decrease_list_width=\33\54
    delete=KEY_DC
    delete_chat=\33\144
    delete_line_after_cursor=KEY_CTRLK
    delete_line_before_cursor=KEY_CTRLU
    delete_msg=KEY_CTRLD
    down=KEY_DOWN
    edit_msg=KEY_CTRLZ
    end=KEY_END
    end_line=KEY_CTRLE
    ext_call=\33\164
    ext_edit=\33\145
    find=\33\57
    find_next=\33\77
    forward_msg=\33\162
    forward_word=
    goto_chat=KEY_CTRLN
    home=KEY_HOME
    increase_list_width=\33\56
    jump_quoted=\33\161
    kill_word=
    left=KEY_LEFT
    linebreak=\033
    next_chat=KEY_TAB
    next_page=KEY_NPAGE
    ok=KEY_RETURN
    open=KEY_CTRLO
    open_link=KEY_CTRLW
    open_msg=\33\167
    other_commands_help=KEY_CTRLV
    paste=\33\166
    prev_chat=KEY_BTAB
    prev_page=KEY_PPAGE
    quit=KEY_CTRLQ
    react=\33\163
    right=KEY_RIGHT
    save=KEY_CTRLR
    select_contact=\33\156
    select_emoji=KEY_CTRLS
    send_msg=KEY_RETURN
    spell=\33\44
    terminal_focus_in=KEY_FOCUS_IN
    terminal_focus_out=KEY_FOCUS_OUT
    terminal_resize=KEY_RESIZE
    toggle_emoji=KEY_CTRLY
    toggle_help=KEY_CTRLG
    toggle_list=KEY_CTRLL
    toggle_top=KEY_CTRLP
    transfer=KEY_CTRLT
    unread_chat=KEY_CTRLF
    up=KEY_UP
  '';

}
