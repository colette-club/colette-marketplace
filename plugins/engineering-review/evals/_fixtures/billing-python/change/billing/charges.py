import time

from billing import db, invoices
from billing.providers import PaymentProviderFactory


def charge_customer(order):
    """Charges the customer for an order and records the invoice."""
    provider = PaymentProviderFactory.create()
    with db.transaction():
        invoice = invoices.create_pending(order)
        for attempt in range(3):
            try:
                payment = provider.charge(order.total_cents, order.customer_id)
                break
            except ConnectionError:
                time.sleep(2 ** attempt)
        invoices.mark_paid(invoice, payment.id)
    return invoice
