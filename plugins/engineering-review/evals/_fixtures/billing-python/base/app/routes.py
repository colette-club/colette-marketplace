from flask import Blueprint, jsonify

from app.auth import require_admin
from billing import invoices

admin = Blueprint("admin", __name__, url_prefix="/admin")


@admin.get("/invoices")
@require_admin
def list_invoices():
    return jsonify(invoices.list_recent())
