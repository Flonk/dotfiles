#!/usr/bin/env python3
"""
Skynet Greeter — a custom greetd greeter using pygame + SDL2 KMS/DRM.

Renders a login screen matching the GRUB theme:
  - Dark background with accent border
  - Logo on the right side
  - Username + password input on the left side
  - Talks to greetd over its IPC socket

All visual parameters are injected via environment variables at build time
by the Nix module.
"""

import json
import os
import socket
import struct
import sys
import time

import pygame  # noqa: E402

# ---------------------------------------------------------------------------
# Configuration from environment
# ---------------------------------------------------------------------------
BG_COLOR = os.environ.get("GREETER_BG_COLOR", "#141519")
BORDER_COLOR = os.environ.get("GREETER_BORDER_COLOR", "#D4A645")
TEXT_COLOR = os.environ.get("GREETER_TEXT_COLOR", "#ffffff")
TEXT_DIM = os.environ.get("GREETER_TEXT_DIM", "#555560")
BAR_BG = os.environ.get("GREETER_BAR_BG", "#1C1D24")
BAR_FG = os.environ.get("GREETER_BAR_FG", "#8B92A8")
BORDER_WIDTH = int(os.environ.get("GREETER_BORDER_WIDTH", "4"))
LOGO_PATH = os.environ.get("GREETER_LOGO", "")
FONT_PATH = os.environ.get("GREETER_FONT", "")
FONT_BOLD_PATH = os.environ.get("GREETER_FONT_BOLD", "")
DEFAULT_USER = os.environ.get("GREETER_DEFAULT_USER", "")
SESSION_CMD = os.environ.get("GREETER_SESSION_CMD", "Hyprland")
SCREEN_W = int(os.environ.get("GREETER_WIDTH", "0"))
SCREEN_H = int(os.environ.get("GREETER_HEIGHT", "0"))

SELECT_BORDER = 2
SELECT_PADDING = 12
INPUT_HEIGHT = 44


# ---------------------------------------------------------------------------
# Color helpers
# ---------------------------------------------------------------------------
def hex_to_rgb(h: str) -> tuple[int, int, int]:
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))


def hex_to_rgba(h: str, a: int = 255) -> tuple[int, int, int, int]:
    r, g, b = hex_to_rgb(h)
    return (r, g, b, a)


# ---------------------------------------------------------------------------
# greetd IPC
# ---------------------------------------------------------------------------
class GreetdIPC:
    """Communicate with greetd over its UNIX socket."""

    def __init__(self):
        sock_path = os.environ.get("GREETD_SOCK", "/run/greetd.sock")
        self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.sock.connect(sock_path)

    def _send(self, payload: dict):
        data = json.dumps(payload).encode("utf-8")
        self.sock.sendall(struct.pack("=I", len(data)) + data)

    def _recv(self) -> dict:
        raw_len = self._recvall(4)
        length = struct.unpack("=I", raw_len)[0]
        data = self._recvall(length)
        return json.loads(data.decode("utf-8"))

    def _recvall(self, n: int) -> bytes:
        buf = b""
        while len(buf) < n:
            chunk = self.sock.recv(n - len(buf))
            if not chunk:
                raise ConnectionError("greetd socket closed")
            buf += chunk
        return buf

    def create_session(self, username: str) -> dict:
        self._send({"type": "create_session", "username": username})
        return self._recv()

    def post_auth(self, response: str | None = None) -> dict:
        msg: dict = {"type": "post_auth_message_response"}
        if response is not None:
            msg["response"] = response
        self._send(msg)
        return self._recv()

    def start_session(self, cmd: list[str], env: list[str] | None = None) -> dict:
        self._send({
            "type": "start_session",
            "cmd": cmd,
            "env": env or [],
        })
        return self._recv()

    def cancel_session(self):
        self._send({"type": "cancel_session"})
        return self._recv()

    def close(self):
        self.sock.close()


# ---------------------------------------------------------------------------
# Rendering
# ---------------------------------------------------------------------------
class GreeterUI:
    """Pygame-based greeter UI matching the GRUB theme."""

    def __init__(self):
        pygame.init()
        pygame.key.set_repeat(500, 50)

        if SCREEN_W > 0 and SCREEN_H > 0:
            self.width, self.height = SCREEN_W, SCREEN_H
        else:
            info = pygame.display.Info()
            self.width = info.current_w if info.current_w > 0 else 1920
            self.height = info.current_h if info.current_h > 0 else 1080

        # Try fullscreen kmsdrm, fall back to windowed for testing
        try:
            self.screen = pygame.display.set_mode(
                (self.width, self.height), pygame.FULLSCREEN | pygame.NOFRAME
            )
        except pygame.error:
            self.screen = pygame.display.set_mode((self.width, self.height))

        pygame.display.set_caption("Skynet Greeter")
        pygame.mouse.set_visible(False)

        # Fonts
        font_size_normal = max(18, self.height // 54)  # ~20px at 1080p
        font_size_small = max(12, self.height // 72)   # ~15px at 1080p
        font_size_label = max(14, self.height // 64)   # ~17px at 1080p

        if FONT_PATH and os.path.isfile(FONT_PATH):
            self.font = pygame.font.Font(FONT_PATH, font_size_normal)
            self.font_small = pygame.font.Font(FONT_PATH, font_size_small)
            self.font_label = pygame.font.Font(FONT_PATH, font_size_label)
        else:
            self.font = pygame.font.SysFont("DejaVu Sans Mono", font_size_normal)
            self.font_small = pygame.font.SysFont("DejaVu Sans Mono", font_size_small)
            self.font_label = pygame.font.SysFont("DejaVu Sans Mono", font_size_label)

        if FONT_BOLD_PATH and os.path.isfile(FONT_BOLD_PATH):
            self.font_bold = pygame.font.Font(FONT_BOLD_PATH, font_size_normal)
        else:
            self.font_bold = pygame.font.SysFont("DejaVu Sans Mono", font_size_normal, bold=True)

        # Logo
        self.logo = None
        if LOGO_PATH and os.path.isfile(LOGO_PATH):
            try:
                self.logo = pygame.image.load(LOGO_PATH).convert_alpha()
            except pygame.error:
                self.logo = None

        # State
        self.username = DEFAULT_USER
        self.password = ""
        self.phase = "username" if not DEFAULT_USER else "password"
        self.error_msg = ""
        self.error_time = 0.0
        self.cursor_visible = True
        self.cursor_timer = 0

        # Clock for framerate
        self.clock = pygame.time.Clock()

    def draw(self):
        w, h = self.width, self.height
        bg = hex_to_rgb(BG_COLOR)
        border = hex_to_rgb(BORDER_COLOR)
        text_col = hex_to_rgb(TEXT_COLOR)
        text_dim = hex_to_rgb(TEXT_DIM)
        bar_bg = hex_to_rgb(BAR_BG)
        bar_fg = hex_to_rgb(BAR_FG)

        # Background
        self.screen.fill(bg)

        # Border (same as GRUB: 4px border around entire screen)
        bw = BORDER_WIDTH
        pygame.draw.rect(self.screen, border, (0, 0, w, bw))          # top
        pygame.draw.rect(self.screen, border, (0, h - bw, w, bw))     # bottom
        pygame.draw.rect(self.screen, border, (0, 0, bw, h))          # left
        pygame.draw.rect(self.screen, border, (w - bw, 0, bw, h))     # right

        # --- Left side: login form (vertically centered) ---
        form_x = int(w * 0.05)
        form_w = int(w * 0.40)

        # Measure total form height to center it
        title_surf = self.font_bold.render("Login", True, text_col)
        label_h = self.font_label.get_height() + 4  # label + gap
        field_gap = int(h * 0.03)
        total_form_h = (
            title_surf.get_height()   # title
            + field_gap               # gap after title
            + label_h + INPUT_HEIGHT  # username label + input
            + field_gap               # gap between fields
            + label_h + INPUT_HEIGHT  # password label + input
        )
        form_y = (h - total_form_h) // 2

        # Title
        self.screen.blit(title_surf, (form_x, form_y))

        # Input fields
        field_y = form_y + title_surf.get_height() + field_gap
        field_w = form_w

        # Username field
        self._draw_input_field(
            form_x, field_y, field_w,
            label="Username",
            value=self.username,
            active=(self.phase == "username"),
            text_col=text_col, dim_col=text_dim, bar_bg=bar_bg,
            accent=border, bar_fg=bar_fg,
        )

        # Password field
        pw_y = field_y + label_h + INPUT_HEIGHT + field_gap
        self._draw_input_field(
            form_x, pw_y, field_w,
            label="Password",
            value="*" * len(self.password),
            active=(self.phase == "password"),
            text_col=text_col, dim_col=text_dim, bar_bg=bar_bg,
            accent=border, bar_fg=bar_fg,
        )

        # Error message
        if self.error_msg and (time.time() - self.error_time) < 5.0:
            err_surf = self.font_small.render(self.error_msg, True, (200, 60, 60))
            err_y = pw_y + INPUT_HEIGHT + int(h * 0.03)
            self.screen.blit(err_surf, (form_x, err_y))

        # Footer hint (like GRUB's bottom label)
        hint = "enter: login"
        hint_surf = self.font_small.render(hint, True, text_dim)
        hint_y = int(h * 0.95)
        self.screen.blit(hint_surf, (form_x, hint_y))

        # Session indicator
        sess_text = f"session: {SESSION_CMD}"
        sess_surf = self.font_small.render(sess_text, True, text_dim)
        sess_y = int(h * 0.91)
        self.screen.blit(sess_surf, (form_x, sess_y))

        # --- Right side: logo (matching GRUB placement) ---
        if self.logo:
            logo_x = int(w * 0.75) - self.logo.get_width() // 2
            logo_y = int(h * 0.50) - self.logo.get_height() // 2
            self.screen.blit(self.logo, (logo_x, logo_y))

        pygame.display.flip()

    def _draw_input_field(
        self, x, y, w, *, label, value, active,
        text_col, dim_col, bar_bg, accent, bar_fg,
    ):
        """Draw a labeled input field with optional cursor."""
        # Label
        label_surf = self.font_label.render(label, True, bar_fg)
        self.screen.blit(label_surf, (x, y - label_surf.get_height() - 4))

        # Background box
        box_rect = pygame.Rect(x, y, w, INPUT_HEIGHT)
        pygame.draw.rect(self.screen, bar_bg, box_rect)

        if active:
            # Accent border (like selection highlight in GRUB)
            pygame.draw.rect(self.screen, accent, box_rect, SELECT_BORDER)
        else:
            # Subtle border
            darker = tuple(max(0, c - 10) for c in bar_bg)
            pygame.draw.rect(self.screen, darker, box_rect, 1)

        # Text
        text_x = x + SELECT_PADDING
        text_y = y + (INPUT_HEIGHT - self.font.get_height()) // 2
        if value:
            val_surf = self.font.render(value, True, text_col)
            self.screen.blit(val_surf, (text_x, text_y))
            cursor_x = text_x + val_surf.get_width() + 2
        else:
            cursor_x = text_x

        # Blinking cursor
        if active and self.cursor_visible:
            cursor_h = self.font.get_height()
            pygame.draw.rect(
                self.screen, accent,
                (cursor_x, text_y, 2, cursor_h),
            )

    def run(self):
        """Main event loop."""
        running = True
        while running:
            self.cursor_timer += 1
            if self.cursor_timer >= 30:  # toggle every ~0.5s at 60fps
                self.cursor_visible = not self.cursor_visible
                self.cursor_timer = 0

            for event in pygame.event.get():
                if event.type == pygame.QUIT:
                    running = False

                elif event.type == pygame.KEYDOWN:
                    self.cursor_visible = True
                    self.cursor_timer = 0

                    if event.key == pygame.K_ESCAPE:
                        if self.phase == "password" and not DEFAULT_USER:
                            # Go back to username
                            self.phase = "username"
                            self.password = ""
                            self.error_msg = ""
                        else:
                            running = False

                    elif event.key == pygame.K_RETURN:
                        if self.phase == "username":
                            if self.username.strip():
                                self.phase = "password"
                        elif self.phase == "password":
                            self._attempt_login()

                    elif event.key == pygame.K_BACKSPACE:
                        if self.phase == "username":
                            self.username = self.username[:-1]
                        elif self.phase == "password":
                            self.password = self.password[:-1]

                    elif event.key == pygame.K_TAB:
                        if self.phase == "username" and self.username.strip():
                            self.phase = "password"
                        elif self.phase == "password" and not DEFAULT_USER:
                            self.phase = "username"

                    elif event.unicode and event.unicode.isprintable():
                        if self.phase == "username":
                            self.username += event.unicode
                        elif self.phase == "password":
                            self.password += event.unicode

            self.draw()
            self.clock.tick(60)

        pygame.quit()

    def _attempt_login(self):
        """Try to authenticate and start session via greetd IPC."""
        try:
            ipc = GreetdIPC()

            # Step 1: create session
            resp = ipc.create_session(self.username.strip())

            if resp.get("type") == "error":
                self._show_error(resp.get("description", "Session creation failed"))
                ipc.close()
                return

            # Step 2: handle auth messages (typically PAM asks for password)
            while resp.get("type") == "auth_message":
                msg_type = resp.get("auth_message_type", "")
                if msg_type in ("visible", "secret"):
                    resp = ipc.post_auth(self.password)
                else:
                    # info or error message from PAM — acknowledge and continue
                    resp = ipc.post_auth(None)

            if resp.get("type") == "error":
                self._show_error(resp.get("description", "Authentication failed"))
                ipc.close()
                return

            if resp.get("type") == "success":
                # Step 3: start the session
                cmd = SESSION_CMD.split()
                resp = ipc.start_session(cmd)

                if resp.get("type") == "error":
                    self._show_error(resp.get("description", "Session start failed"))
                    ipc.close()
                    return

                # Success! The greeter process should now exit so greetd
                # can start the user session.
                # Use os._exit(0) to bypass pygame/SDL Wayland teardown — a
                # graceful pygame.quit() stalls waiting for cage to ack the
                # Wayland disconnect, causing ~90s delay before Hyprland starts.
                ipc.close()
                os._exit(0)

        except Exception as e:
            self._show_error(str(e))

        # Reset password for retry
        self.password = ""

    def _show_error(self, msg: str):
        self.error_msg = msg
        self.error_time = time.time()


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------
def main():
    ui = GreeterUI()
    ui.run()


if __name__ == "__main__":
    main()
