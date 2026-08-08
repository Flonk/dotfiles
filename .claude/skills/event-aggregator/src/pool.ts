/**
 * Run `work` over `items` with at most `limit` in flight, handing each result
 * back as it lands rather than after the whole batch. Scrapers vary from
 * 200ms to 4 minutes, so a barrier here would waste most of the wall clock.
 */
export async function pool<T, R>(
  items: T[],
  limit: number,
  work: (item: T) => Promise<R>,
  onDone: (item: T, result: R | null, err: Error | null) => void,
): Promise<void> {
  const queue = [...items];
  const width = Math.max(1, Math.min(limit, queue.length));

  const worker = async (): Promise<void> => {
    for (;;) {
      const item = queue.shift();
      if (item === undefined) return;
      try {
        onDone(item, await work(item), null);
      } catch (e) {
        onDone(item, null, e instanceof Error ? e : new Error(String(e)));
      }
    }
  };

  await Promise.all(Array.from({ length: width }, worker));
}
