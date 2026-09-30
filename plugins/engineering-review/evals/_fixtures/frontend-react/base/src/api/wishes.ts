export type Wish = { id: string; title: string; photoUrl: string; archived: boolean };

export async function listWishes(): Promise<Wish[]> {
  const response = await fetch("/api/wishes");
  if (!response.ok) throw new Error(`listWishes failed: ${response.status}`);
  return response.json();
}
