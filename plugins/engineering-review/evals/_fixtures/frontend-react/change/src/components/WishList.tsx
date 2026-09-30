import { archiveWish, Wish } from "../api/wishes";
import { TrashIcon } from "./icons";

type Props = { wishes: Wish[]; onArchived: (id: string) => void };

export function WishList({ wishes, onArchived }: Props) {
  return (
    <ul className="wish-list">
      {wishes.map((wish, index) => (
        <li key={index}>
          <img src={wish.photoUrl} />
          <span>{wish.title}</span>
          <span style={{ color: wish.archived ? "grey" : "green" }}>●</span>
          <button onClick={() => archiveWish(wish.id).then(() => onArchived(wish.id))}>
            <TrashIcon />
          </button>
        </li>
      ))}
    </ul>
  );
}
