import { die, readSecret } from "./proc.js";

const paths = (): Record<string, string> => JSON.parse(process.env.CRDP_LINKS ?? "{}");

export const linkNames = () => Object.keys(paths());

const url = (name: string) => new URL(readSecret(paths()[name])).href;

export function resolve(target: string): string {
  if (target in paths()) return url(target);
  if (/^https?:\/\//.test(target)) return new URL(target).href;
  return die(`unknown link ${target}, expected a URL or one of ${linkNames().join(", ")}`);
}

export function links(name?: string): void {
  if (name !== undefined) {
    if (!(name in paths())) die(`unknown link ${name}, expected one of ${linkNames().join(", ")}`);
    console.log(url(name));
    return;
  }
  for (const n of linkNames()) console.log(`${n}\t${url(n)}`);
}
