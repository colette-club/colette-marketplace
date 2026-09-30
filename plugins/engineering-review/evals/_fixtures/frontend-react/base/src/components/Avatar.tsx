type Props = { name: string; photoUrl: string };

export function Avatar({ name, photoUrl }: Props) {
  return <img src={photoUrl} alt={`Photo of ${name}`} className="avatar" />;
}
