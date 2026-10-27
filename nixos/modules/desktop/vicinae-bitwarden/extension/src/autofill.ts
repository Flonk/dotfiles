import { execFileSync } from "child_process";
import { LaunchProps } from "@vicinae/api";
import { isLocked, listItems, matchItems } from "./rbw";
import { autofillCredentials } from "./fill";

export default async function Autofill(props: LaunchProps<{ arguments: { query: string } }>) {
  const query = props.arguments.query ?? "";
  if (isLocked()) {
    execFileSync("vicinae", [
      "deeplink",
      `vicinae://launch/@flo/vicinae-bitwarden/search?arguments=${encodeURIComponent(JSON.stringify({ query }))}`,
    ]);
    return;
  }
  const [item] = matchItems(listItems(), query);
  if (!item) {
    execFileSync("notify-send", ["🔑 No vault match", query]);
    return;
  }
  await autofillCredentials(item, "");
}
