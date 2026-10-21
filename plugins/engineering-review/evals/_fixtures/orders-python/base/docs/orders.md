# Orders

The shop's data lives in MySQL (`app/database.py`, schema in `shop/schema.sql`).

- `cancel_order(order_id)` — cancels an open order and puts its items back in stock.
- `restock(shipment)` — adds a supplier shipment to stock, one product at a time.
