# pyright: reportMissingImports=false, reportUnknownMemberType=false, reportMissingParameterType=false, reportUnknownParameterType=false, reportUnusedVariable=false, reportUnknownVariableType=false, reportUnusedCallResult=false, reportUnknownArgumentType=false, reportUnknownLambdaType=false, reportReturnType=false, reportUninitializedInstanceVariable=false, reportUnusedImport=false, reportUnannotatedClassAttribute=false
import os
import shutil
import signal
import subprocess
import sys
import tempfile
import time

from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.support.ui import WebDriverWait
from selenium_stealth import stealth
from xdg_base_dirs import xdg_config_home


def _log(msg, style="dim"):
    styles = {"dim": "\033[2m", "bold": "\033[1m", "green": "\033[1;32m"}
    reset = "\033[0m"
    print(f"{styles.get(style, '')}{msg}{reset}", file=sys.stderr, flush=True)


class VPN3ITConnect:
    def __init__(self, vpn_url, username, password, headless=True):
        self.vpn_url = vpn_url
        self.username = username
        self.password = password
        self.headless = headless
        self.driver = None

    def _handle_open_sessions_page(self):
        # Ivanti intermittently shows a "maximum number of open user sessions"
        # confirmation page (welcome.cgi?p=user-confirm) after auth. Tick every
        # listed session and click continue so the login can complete.
        try:
            buttons = self.driver.find_elements(By.CSS_SELECTOR, "#btnContinue")
            if not buttons:
                return
            checkboxes = self.driver.find_elements(
                By.CSS_SELECTOR, 'input[name="postfixSID"]'
            )
            if not checkboxes:
                return
            for cb in checkboxes:
                if not cb.is_selected():
                    cb.click()
            _log("Open sessions page detected; closing existing sessions...")
            buttons[0].click()
        except Exception:
            # Page may transition mid-inspection; the next poll retries.
            pass

    def _login_form_present(self):
        try:
            fields = self.driver.find_elements(By.CSS_SELECTOR, "#username")
            return any(f.is_displayed() for f in fields)
        except Exception:
            return False

    def _visible_text(self):
        try:
            txt = self.driver.find_element(By.TAG_NAME, "body").text.strip()
            return txt or None
        except Exception:
            return None

    def _capture_and_render(self, reason):
        if not self.driver:
            return
        try:
            try:
                self.driver.execute_script(
                    "document.documentElement.style.zoom='200%'"
                )
                time.sleep(0.3)
            except Exception:
                pass
            fd, path = tempfile.mkstemp(prefix="vpn3it-fail-", suffix=".png")
            os.close(fd)
            if not self.driver.save_screenshot(path):
                _log("(could not save screenshot)")
                return
            _log(f"--- Browser at failure ({reason}) ---", "bold")
            if shutil.which("chafa"):
                subprocess.run(["chafa", path])
            else:
                _log(f"(chafa not found; screenshot saved to {path})")
        except Exception as e:
            _log(f"(could not capture screenshot: {e})")

    def signal_handler(self, _signum, _frame):
        print("\nCaught SIGINT, shutting down openconnect...", file=sys.stderr)
        subprocess.run(["sudo", "pkill", "-SIGINT", "openconnect"])
        if self.driver:
            try:
                self.driver.quit()
            except Exception:
                pass
        sys.exit(0)

    def connect(self):
        signal.signal(signal.SIGINT, self.signal_handler)

        user_data_dir = os.path.join(xdg_config_home(), "chromedriver", "pulsevpn")
        os.makedirs(user_data_dir, exist_ok=True)

        options = webdriver.ChromeOptions()
        if self.headless:
            options.add_argument("--headless=new")
        options.add_argument("--no-sandbox")
        options.add_argument("--disable-gpu")
        options.add_argument("--window-size=1920,1080")
        options.add_argument(f"--user-data-dir={user_data_dir}")

        try:
            _log("Launching...", "bold")
            _log(f"Starting {'headless ' if self.headless else ''}Chromium...")
            self.driver = webdriver.Chrome(options=options)

            stealth(
                self.driver,
                languages=["en-US", "en"],
                vendor="Google Inc.",
                platform="Win32",
                webgl_vendor="Intel Inc.",
                renderer="Intel Iris OpenGL Engine",
                fix_hairline=True,
            )

            _log(f"Navigating to {self.vpn_url}...")
            self.driver.get(self.vpn_url)

            if self.headless:
                _log("Waiting for login form...")
                wait = WebDriverWait(self.driver, 30)

                try:
                    username_field = wait.until(
                        EC.presence_of_element_located((By.CSS_SELECTOR, "#username"))
                    )
                    password_field = wait.until(
                        EC.presence_of_element_located((By.CSS_SELECTOR, "#password"))
                    )
                    password_secondary_field = wait.until(
                        EC.presence_of_element_located(
                            (By.CSS_SELECTOR, "#passwordSecondary")
                        )
                    )
                except Exception:
                    print("Error: Timed out waiting for login form fields", file=sys.stderr)
                    self._capture_and_render("login form never appeared")
                    sys.exit(1)

                print("Enter Authy token: ", end="", flush=True)
                token = input()

                username_field.send_keys(self.username)
                password_field.send_keys(token)
                password_secondary_field.send_keys(self.password)

                try:
                    submit_button = wait.until(
                        EC.element_to_be_clickable(
                            (By.CSS_SELECTOR, 'button[type="submit"]')
                        )
                    )
                except Exception:
                    print("Error: Timed out waiting for submit button", file=sys.stderr)
                    self._capture_and_render("submit button never appeared")
                    sys.exit(1)

                _log("Authenticating...", "bold")
                submit_button.click()
            else:
                _log("Log in manually in the browser window...", "bold")

            _log("Obtaining DSID Token...", "bold")
            dsid = None
            rejected = False
            start = time.time()
            deadline = start + (90 if self.headless else 300)
            while time.time() < deadline:
                dsid = self.driver.get_cookie("DSID")
                if dsid:
                    break
                self._handle_open_sessions_page()
                if self.headless and time.time() - start > 15 and self._login_form_present():
                    rejected = True
                    break
                time.sleep(1)
            if not dsid:
                if rejected:
                    print(
                        "Error: login rejected — still on the login form after "
                        "submit (bad token, or locked/expired access?)",
                        file=sys.stderr,
                    )
                    reason = "login rejected"
                else:
                    print(
                        "Error: timed out waiting for DSID cookie "
                        "(login did not complete)",
                        file=sys.stderr,
                    )
                    reason = "DSID cookie never appeared"
                msg = self._visible_text()
                if msg:
                    print("--- What the portal is showing ---", file=sys.stderr)
                    print(msg, file=sys.stderr)
                self._capture_and_render(reason)
                sys.exit(1)

            self.driver.quit()
            self.driver = None

            _log(f"DSID cookie acquired: {dsid['value'][:8]}...")

            subprocess.run(
                [
                    "sudo",
                    "openconnect",
                    "-b",
                    "-C",
                    dsid["value"],
                    "--protocol=pulse",
                    self.vpn_url,
                ]
            )

            time.sleep(3)
            _log("openconnect launched in background")
            _log("VPN Connection Established!", "green")

        except SystemExit:
            raise
        except Exception as e:
            print(f"Error: {e}", file=sys.stderr)
            self._capture_and_render(f"unexpected error: {type(e).__name__}")
            sys.exit(1)
        finally:
            if self.driver:
                try:
                    self.driver.quit()
                except Exception:
                    pass


if __name__ == "__main__":
    headless = True
    args = [a for a in sys.argv[1:] if a != "--no-headless"]
    if len(args) != len(sys.argv[1:]):
        headless = False

    if len(args) != 3:
        print(
            f"Usage: {sys.argv[0]} [--no-headless] <vpn_url> <username_file> <password_file>",
            file=sys.stderr,
        )
        sys.exit(1)

    vpn_url = args[0]
    username_file = args[1]
    password_file = args[2]

    with open(username_file, "r") as f:
        username = f.read().strip()

    with open(password_file, "r") as f:
        password = f.read().strip()

    vpn = VPN3ITConnect(vpn_url, username, password, headless=headless)
    vpn.connect()
