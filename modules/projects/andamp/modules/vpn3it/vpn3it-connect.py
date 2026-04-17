import os
import signal
import subprocess
import sys
import time

from selenium import webdriver
from selenium.webdriver.chrome.service import Service
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
    def __init__(self, vpn_url, username, password):
        self.vpn_url = vpn_url
        self.username = username
        self.password = password
        self.driver = None

    def signal_handler(self, signum, frame):
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
        options.add_argument("--headless=new")
        options.add_argument("--no-sandbox")
        options.add_argument("--disable-gpu")
        options.add_argument("--window-size=1920,1080")
        options.add_argument(f"--user-data-dir={user_data_dir}")

        try:
            _log("Launching...", "bold")
            _log("Starting headless Chromium...")
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
                sys.exit(1)

            _log("Authenticating...", "bold")
            submit_button.click()

            _log("Obtaining DSID Token...", "bold")
            try:
                dsid = WebDriverWait(self.driver, timeout=300, poll_frequency=1).until(
                    lambda d: d.get_cookie("DSID")
                )
            except Exception:
                print("Error: Timed out waiting for DSID cookie", file=sys.stderr)
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
            sys.exit(1)
        finally:
            if self.driver:
                try:
                    self.driver.quit()
                except Exception:
                    pass


if __name__ == "__main__":
    if len(sys.argv) != 4:
        print(
            f"Usage: {sys.argv[0]} <vpn_url> <username_file> <password_file>",
            file=sys.stderr,
        )
        sys.exit(1)

    vpn_url = sys.argv[1]
    username_file = sys.argv[2]
    password_file = sys.argv[3]

    with open(username_file, "r") as f:
        username = f.read().strip()

    with open(password_file, "r") as f:
        password = f.read().strip()

    vpn = VPN3ITConnect(vpn_url, username, password)
    vpn.connect()
