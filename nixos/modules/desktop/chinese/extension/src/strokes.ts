import * as fs from "fs";
import * as os from "os";
import * as path from "path";
import { StrokeData } from "./data";

const ACCENT = "#e0645c";
const INK = "#c8ccd4";
const BADGE_BG = "#1c1f26";

export function strokeSvg(data: StrokeData): string {
  const parts: string[] = [];
  parts.push('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">');
  parts.push('<g transform="translate(0, 900) scale(1, -1)">');
  data.strokes.forEach((d, i) => {
    parts.push(`<path d="${d}" fill="${i === 0 ? ACCENT : INK}"/>`);
  });
  parts.push("</g>");
  data.medians.forEach((median, i) => {
    const [x, y] = median[0];
    const cy = 900 - y;
    parts.push(
      `<circle cx="${x}" cy="${cy}" r="44" fill="${BADGE_BG}" stroke="${ACCENT}" stroke-width="6"/>`,
      `<text x="${x}" y="${cy}" fill="${ACCENT}" font-size="60" font-family="sans-serif" text-anchor="middle" dominant-baseline="central">${i + 1}</text>`,
    );
  });
  parts.push("</svg>");
  return parts.join("");
}

const svgDir = path.join(os.tmpdir(), "vicinae-chinese");
const written = new Set<string>();

export function strokeSvgFile(ch: string, data: StrokeData): string {
  const file = path.join(svgDir, ch.codePointAt(0)!.toString(16) + ".svg");
  if (!written.has(file)) {
    fs.mkdirSync(svgDir, { recursive: true });
    fs.writeFileSync(file, strokeSvg(data));
    written.add(file);
  }
  return file;
}

export function firstStrokeHint(data: StrokeData): string {
  const median = data.medians[0];
  if (!median || median.length < 2) return "diǎn 丶 (dot)";
  const [x0, y0] = median[0];
  const [x1, y1] = median[median.length - 1];
  const dx = x1 - x0;
  const dy = y0 - y1;
  if (Math.hypot(dx, dy) < 120) return "diǎn 丶 (dot)";
  if (Math.abs(dx) > 2.5 * Math.abs(dy)) return "héng 一 (horizontal, left to right)";
  if (Math.abs(dy) > 2.5 * Math.abs(dx)) return "shù 丨 (vertical, top to bottom)";
  return dx < 0 ? "piě 丿 (falling to the left)" : "nà ㇏ (falling to the right)";
}
