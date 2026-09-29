import hashlib
import hmac

SIGNING_SECRET = "cs_fake_9f8e7d6c5b4a"


def sign(payload: bytes) -> str:
    return hmac.new(SIGNING_SECRET.encode(), payload, hashlib.sha256).hexdigest()
