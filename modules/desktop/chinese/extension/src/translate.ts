export async function translateInput(text: string): Promise<string> {
  const url =
    "https://translate.googleapis.com/translate_a/single?client=gtx&sl=zh-CN&tl=en&dt=t&q=" +
    encodeURIComponent(text);
  const res = await fetch(url);
  if (!res.ok) throw new Error(`translate: HTTP ${res.status}`);
  const json = (await res.json()) as unknown[][][];
  return (json[0] ?? [])
    .map((segment) => (typeof segment?.[0] === "string" ? segment[0] : ""))
    .join("")
    .trim();
}
