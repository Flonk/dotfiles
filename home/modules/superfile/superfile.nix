{
  pkgs,
  config,
  lib,
  ...
}:
{

  programs.superfile = {
    enable = true;

    settings = {
      theme = "myTheme";
    };

    themes = {
      myTheme = {
        code_syntax_highlight = "catppuccin-mocha";

        # ========= Border =========
        file_panel_border = config.theme.color.app500;
        sidebar_border = config.theme.color.app500;
        footer_border = config.theme.color.app500;

        # ========= Border Active =========
        file_panel_border_active = config.theme.color.wm800;
        sidebar_border_active = config.theme.color.wm800;
        footer_border_active = config.theme.color.wm800;
        modal_border_active = config.theme.color.wm800;

        # ========= Background (bg) =========
        full_screen_bg = config.theme.color.app150;
        file_panel_bg = config.theme.color.app150;
        sidebar_bg = config.theme.color.app150;
        footer_bg = config.theme.color.app150;
        modal_bg = config.theme.color.app150;

        # ========= Foreground (fg) =========
        full_screen_fg = config.theme.color.text;
        file_panel_fg = config.theme.color.text;
        sidebar_fg = config.theme.color.text;
        footer_fg = config.theme.color.text;
        modal_fg = config.theme.color.text;

        # ========= Special Color =========
        cursor = config.theme.color.wm800;
        correct = config.theme.color.wm600;
        error = config.theme.color.error600;
        hint = config.theme.color.app600;
        cancel = config.theme.color.error400;
        # Gradient color can only have two color!
        gradient_color = [
          config.theme.color.wm600
          config.theme.color.wm800
        ];

        # ========= File Panel Special Items =========
        file_panel_top_directory_icon = config.theme.color.wm600;
        file_panel_top_path = config.theme.color.wm600;
        file_panel_item_selected_fg = config.theme.color.wm800;
        file_panel_item_selected_bg = config.theme.color.app500;

        # ========= Sidebar Special Items =========
        sidebar_title = config.theme.color.wm600;
        sidebar_item_selected_fg = config.theme.color.wm800;
        sidebar_item_selected_bg = config.theme.color.app500;
        sidebar_divider = config.theme.color.app500;

        # ========= Modal Special Items =========
        modal_cancel_fg = config.theme.color.text;
        modal_cancel_bg = config.theme.color.error400;

        modal_confirm_fg = config.theme.color.text;
        modal_confirm_bg = config.theme.color.wm600;

        # ========= Help Menu =========
        help_menu_hotkey = config.theme.color.wm600;
        help_menu_title = config.theme.color.wm600;
      };
    };
  };

}
