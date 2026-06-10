import pytest
import sys
import os

# Add src/python to path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import mcp_server

def test_lookup_cpt_code():
    res = mcp_server.lookup_cpt_code("99214")
    assert "99214" in res
    assert "Office or other outpatient visit" in res

    res_missing = mcp_server.lookup_cpt_code("00000")
    assert "00000" in res_missing
    assert "Description not found" in res_missing

def test_lookup_icd_code():
    res = mcp_server.lookup_icd_code("I10")
    assert "I10" in res
    assert "hypertension" in res

    # Test prefix matching
    res_prefix = mcp_server.lookup_icd_code("E11")
    assert "E11" in res_prefix
    assert "diabetes" in res_prefix

    res_missing = mcp_server.lookup_icd_code("XYZ")
    assert "XYZ" in res_missing
    assert "Description not found" in res_missing

def test_validate_diagnosis_procedure():
    # Valid combination (I10 hypertension supports 93000 Electrocardiogram)
    res_val = mcp_server.validate_diagnosis_procedure("I10", "93000")
    assert "VALID" in res_val
    assert "supports" in res_val

    # Invalid combination (F32 Depression does not support 93000 Electrocardiogram)
    res_inval = mcp_server.validate_diagnosis_procedure("F32.9", "93000")
    assert "INVALID" in res_inval
    assert "does not support" in res_inval
