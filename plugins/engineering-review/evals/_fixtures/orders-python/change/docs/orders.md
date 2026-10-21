# Orders

The shop's data lives in MySQL (`app/database.py`, schema in `shop/schema.sql`).

- `cancel_order(order_id)` — cancels an open order and puts its items back in stock.
- `restock(shipment)` — adds a supplier shipment to stock, one product at a time.
- `place_order(order_id, cart)` (`shop/checkout.py`) — reserves stock for each cart item, refreshes each product's price from the catalogue (`shop/pricing.py`), then writes the order's lines and adds them to its total. Raises `OutOfStock` when an item is short; nothing is written then.
