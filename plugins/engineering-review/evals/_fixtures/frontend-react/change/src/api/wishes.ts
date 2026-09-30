export type Wish = { id: string; title: string; photoUrl: string; archived: boolean };

export async function listWishes(): Promise<Wish[]> {
  const response = await fetch("/api/wishes");
  if (!response.ok) throw new Error(`listWishes failed: ${response.status}`);
  return response.json();
}

export async function archiveWish(id: string): Promise<void> {
  const response = await fetch(`/api/wishes/${id}/archive`, { method: "POST" });
  if (!response.ok) throw new Error(`archiveWish failed: ${response.status}`);
}
