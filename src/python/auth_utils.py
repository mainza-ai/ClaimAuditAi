"""PBKDF2 password hashing for ClaimAuditAI.

Provides hash_password() and verify_password() with backward-compatible
HMAC-SHA256 legacy fallback for existing credentials created via
$SYSTEM.Encryption.HMACSHA with static salt "ClaimAuditAI_Salt".

Usage (ObjectScript via Embedded Python):
    Set py = ##class(%SYS.Python).Import("auth_utils")
    Set newHash = py."hash_password"(tPassword)
    Set match = py."verify_password"(tStoredHash, tPassword)
"""

import hashlib
import os
import base64
import json
import hmac as _hmac

PBKDF2_ITERATIONS = 100000
SALT_LENGTH = 32
HASH_LENGTH = 32
LEGACY_SALT = b"ClaimAuditAI_Salt"


def hash_password(password):
    """Hash a password using PBKDF2-SHA256.

    Returns JSON string: {"hash":<b64>,"salt":<b64>,"iterations":<int>}
    """
    salt = os.urandom(SALT_LENGTH)
    key = hashlib.pbkdf2_hmac(
        "sha256",
        password.encode("utf-8"),
        salt,
        PBKDF2_ITERATIONS,
        dklen=HASH_LENGTH,
    )
    return json.dumps(
        {
            "hash": base64.b64encode(key).decode("ascii"),
            "salt": base64.b64encode(salt).decode("ascii"),
            "iterations": PBKDF2_ITERATIONS,
        },
        separators=(",", ":"),
    )


def verify_password(stored, password):
    """Verify a password against a stored hash.

    Supports two formats:
    1. PBKDF2 (JSON string starting with '{') — verify via hashlib
    2. Legacy HMAC-SHA256 (raw binary string) — verify via hmac

    Returns bool.
    """
    if not stored or not password:
        return False

    pwd_bytes = password.encode("utf-8")

    # Normalize stored to str for format detection
    if isinstance(stored, bytes):
        stored_str = stored.decode("latin-1")
    else:
        stored_str = stored

    # PBKDF2 format (JSON)
    if stored_str.startswith("{"):
        try:
            data = json.loads(stored)
            stored_hash = base64.b64decode(data["hash"])
            stored_salt = base64.b64decode(data["salt"])
            iterations = data.get("iterations", PBKDF2_ITERATIONS)
            key = hashlib.pbkdf2_hmac(
                "sha256", pwd_bytes, stored_salt, iterations, dklen=HASH_LENGTH
            )
            return _hmac.compare_digest(key, stored_hash)
        except Exception:
            return False

    # Legacy HMAC-SHA256 fallback
    try:
        expected = _hmac.new(LEGACY_SALT, pwd_bytes, hashlib.sha256).digest()
        stored_bytes = stored_str.encode("latin-1")
        return _hmac.compare_digest(expected, stored_bytes)
    except Exception:
        return False


def needs_upgrade(stored):
    """Return True if the stored hash is legacy HMAC (should be upgraded)."""
    if not stored:
        return False
    if isinstance(stored, bytes):
        return True
    return not stored.startswith("{")
