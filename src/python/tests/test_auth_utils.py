import json
import pytest
import hmac as _hmac
import hashlib
import auth_utils

def test_hash_password():
    password = "MySecurePassword2026!"
    hashed_json = auth_utils.hash_password(password)
    
    # Assert output is valid JSON
    data = json.loads(hashed_json)
    assert "hash" in data
    assert "salt" in data
    assert "iterations" in data
    assert data["iterations"] == auth_utils.PBKDF2_ITERATIONS

def test_verify_password_pbkdf2():
    password = "MySecurePassword2026!"
    hashed_json = auth_utils.hash_password(password)
    
    # Correct password
    assert auth_utils.verify_password(hashed_json, password) is True
    
    # Incorrect password
    assert auth_utils.verify_password(hashed_json, "WrongPassword!") is False
    
    # Empty stored/password
    assert auth_utils.verify_password("", password) is False
    assert auth_utils.verify_password(hashed_json, "") is False
    assert auth_utils.verify_password(None, password) is False
    assert auth_utils.verify_password(hashed_json, None) is False

def test_verify_password_legacy():
    password = "AuditReview2026!"
    
    # Generate legacy HMAC-SHA256 hash using the same formula
    expected = _hmac.new(auth_utils.LEGACY_SALT, password.encode("utf-8"), hashlib.sha256).digest()
    
    # Correct legacy password
    assert auth_utils.verify_password(expected, password) is True
    assert auth_utils.verify_password(expected.decode("latin-1"), password) is True
    
    # Incorrect legacy password
    assert auth_utils.verify_password(expected, "WrongPassword!") is False
    assert auth_utils.verify_password(expected.decode("latin-1"), "WrongPassword!") is False

def test_needs_upgrade():
    password = "MySecurePassword2026!"
    hashed_pbkdf2 = auth_utils.hash_password(password)
    legacy_hash = _hmac.new(auth_utils.LEGACY_SALT, password.encode("utf-8"), hashlib.sha256).digest()
    
    assert auth_utils.needs_upgrade(hashed_pbkdf2) is False
    assert auth_utils.needs_upgrade(legacy_hash) is True
    assert auth_utils.needs_upgrade(legacy_hash.decode("latin-1")) is True
    assert auth_utils.needs_upgrade(None) is False
    assert auth_utils.needs_upgrade("") is False
