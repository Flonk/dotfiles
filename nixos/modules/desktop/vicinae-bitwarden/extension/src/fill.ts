import { execFileSync, spawn } from "child_process";
import { writeFileSync, mkdtempSync } from "fs";
import { join } from "path";
import { tmpdir } from "os";
import { VaultItem, getPassword } from "./rbw";

const AUTOFILL_JS = `
(function() {
  const pw = document.querySelector('input[type="password"]:not([aria-hidden="true"])');
  if (!pw) return 'no password field found';
  const form = pw.closest('form') || pw.parentElement?.closest('form') || document;
  const inputs = Array.from(form.querySelectorAll('input:not([type="hidden"]):not([type="submit"]):not([type="button"]):not([type="checkbox"]):not([type="radio"])'));
  const pwIdx = inputs.indexOf(pw);
  const userField = inputs.slice(0, pwIdx).reverse().find(el =>
    el.type !== 'password' && (el.offsetWidth > 0 || el.offsetHeight > 0)
  );
  function fill(el, value) {
    const nativeSetter = Object.getOwnPropertyDescriptor(
      Object.getPrototypeOf(el), 'value'
    )?.set || Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set;
    nativeSetter.call(el, value);
    el.dispatchEvent(new Event('input', { bubbles: true }));
    el.dispatchEvent(new Event('change', { bubbles: true }));
  }
  if (userField) fill(userField, __USERNAME__);
  fill(pw, __PASSWORD__);
  pw.focus();
  'ok';
})()
`.trim();

export async function autofillCredentials(item: VaultItem, masterPassword: string) {
  const password = await getPassword(item, masterPassword);
  const username = item.user ?? "";
  const js = AUTOFILL_JS
    .replace("__USERNAME__", JSON.stringify(username))
    .replace("__PASSWORD__", JSON.stringify(password));
  const dir = mkdtempSync(join(process.env.XDG_RUNTIME_DIR ?? tmpdir(), "bw-autofill-"));
  const jsPath = join(dir, "fill.js");
  writeFileSync(jsPath, js, { mode: 0o600 });
  try {
    execFileSync("qutebrowser", [`:jseval --file ${jsPath}`, `:mode-enter insert`]);
  } finally {
    spawn("sh", ["-c", `sleep 5; rm -rf -- '${dir}'`], {
      detached: true,
      stdio: "ignore",
    }).unref();
  }
  execFileSync("notify-send", ["🔑 Autofilled", item.name]);
  execFileSync("vicinae", ["close"]);
}
