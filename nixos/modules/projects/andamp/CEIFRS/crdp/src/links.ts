import { die, readSecret } from "./proc.js";

const paths = (): Record<string, string> => JSON.parse(process.env.CRDP_LINKS ?? "{}");

const url = (name: string) => new URL(readSecret(paths()[name])).href;

export function resolve(target: string): string {
  if (target in paths()) return url(target);
  if (/^https?:\/\//.test(target)) return new URL(target).href;
  return die(`unknown link ${target}, expected a URL or a name from vpn3it crdp links`);
}

export function links(): void {
  for (const name of Object.keys(paths())) console.log(`${name}\t${url(name)}`);
}
