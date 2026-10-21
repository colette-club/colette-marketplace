from sqlalchemy import text

from shop.db import transaction


def cancel_order(order_id):
    """Cancels an open order and puts its items back in stock. Returns False when the order is not open."""
    with transaction() as connection:
        order = connection.execute(
            text("SELECT id, status FROM orders WHERE id = :id FOR UPDATE"), {"id": order_id}
        ).one()
        if order.status != "open":
            return False
        lines = connection.execute(
            text("SELECT product_id, quantity FROM order_lines WHERE order_id = :id"), {"id": order_id}
        ).all()
        for line in lines:
            connection.execute(
                text("UPDATE products SET stock = stock + :quantity WHERE id = :id"),
                {"quantity": line.quantity, "id": line.product_id},
            )
        connection.execute(text("UPDATE orders SET status = 'cancelled' WHERE id = :id"), {"id": order_id})
        return True


def restock(shipment):
    """Adds a supplier shipment to stock. `shipment` lists (product_id, quantity) pairs in delivery order."""
    with transaction() as connection:
        for product_id, quantity in shipment:
            connection.execute(
                text("UPDATE products SET stock = stock + :quantity WHERE id = :id"),
                {"quantity": quantity, "id": product_id},
            )
