from sqlalchemy import text

from shop import pricing
from shop.db import transaction


class OutOfStock(Exception):
    """Raised when a cart item asks for more than is in stock."""


def place_order(order_id, cart):
    """Reserves stock for each cart item, refreshes the prices, then writes the order's lines and total.

    `cart` lists (product_id, quantity) pairs in the order the customer added them.
    """
    with transaction() as connection:
        for product_id, quantity in cart:
            product = connection.execute(
                text("SELECT id, stock FROM products WHERE id = :id FOR UPDATE"), {"id": product_id}
            ).one()
            if product.stock < quantity:
                raise OutOfStock(product_id)
            connection.execute(
                text("UPDATE products SET stock = stock - :quantity WHERE id = :id"),
                {"quantity": quantity, "id": product_id},
            )

        prices = pricing.refresh_prices([product_id for product_id, _ in cart])

        total = 0
        for product_id, quantity in cart:
            connection.execute(
                text(
                    "INSERT INTO order_lines (order_id, product_id, quantity, price_cents) "
                    "VALUES (:order_id, :product_id, :quantity, :price)"
                ),
                {"order_id": order_id, "product_id": product_id, "quantity": quantity, "price": prices[product_id]},
            )
            total += prices[product_id] * quantity
        connection.execute(
            text("UPDATE orders SET total_cents = total_cents + :total WHERE id = :id"),
            {"total": total, "id": order_id},
        )
