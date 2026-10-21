from concurrent.futures import ThreadPoolExecutor

from sqlalchemy import text

from shop.db import transaction

_executor = ThreadPoolExecutor(max_workers=4)


def refresh_prices(product_ids):
    """Copies each product's catalogue price onto the product. Returns {product_id: price_cents}."""
    futures = {product_id: _executor.submit(_refresh, product_id) for product_id in product_ids}
    return {product_id: future.result() for product_id, future in futures.items()}


def _refresh(product_id):
    with transaction() as connection:
        price = connection.execute(
            text("SELECT price_cents FROM catalogue_prices WHERE product_id = :id"), {"id": product_id}
        ).scalar_one()
        connection.execute(
            text("UPDATE products SET price_cents = :price WHERE id = :id"), {"price": price, "id": product_id}
        )
    return price
