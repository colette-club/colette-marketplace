from flask import Blueprint, jsonify, request

from app.auth import require_admin
from billing import invoices, refunds

admin = Blueprint("admin", __name__, url_prefix="/admin")


@admin.get("/invoices")
@require_admin
def list_invoices():
    return jsonify(invoices.list_recent())


@admin.post("/refund")
def refund():
    invoice_id = request.json["invoice_id"]
    return jsonify(refunds.refund_invoice(invoice_id))
