import sys
import os
import pytest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import dx_procedure_validator

def test_parse_cpt_code():
    assert dx_procedure_validator._parse_cpt_code("CPT 99214 - Office visit") == 99214
    assert dx_procedure_validator._parse_cpt_code("99214") == 99214
    assert dx_procedure_validator._parse_cpt_code("H0001") == 1
    assert dx_procedure_validator._parse_cpt_code("H0010") == 10
    assert dx_procedure_validator._parse_cpt_code("XYZ") == 0

def test_parse_icd_prefix():
    assert dx_procedure_validator._parse_icd_prefix("F10.2") == "F"
    assert dx_procedure_validator._parse_icd_prefix("f10.2") == "F"
    assert dx_procedure_validator._parse_icd_prefix("") == ""
    assert dx_procedure_validator._parse_icd_prefix(None) == ""

def test_validate_diagnosis_procedure_insufficient_data():
    res = dx_procedure_validator.validate_diagnosis_procedure("", "99214")
    assert res["valid"] is True
    assert res["flagged"] is False
    assert "Insufficient" in res["reason"]

    res = dx_procedure_validator.validate_diagnosis_procedure("F10.2", None)
    assert res["valid"] is True
    assert res["flagged"] is False
    assert "Insufficient" in res["reason"]

def test_validate_diagnosis_procedure_unparseable():
    res = dx_procedure_validator.validate_diagnosis_procedure("F10.2", "XYZ")
    assert res["valid"] is True
    assert res["flagged"] is False
    assert "Could not parse" in res["reason"]

def test_validate_diagnosis_procedure_valid_f_chapter():
    # F with H0001 - H0049
    res = dx_procedure_validator.validate_diagnosis_procedure("F10.2", "H0010")
    assert res["valid"] is True
    assert res["flagged"] is False
    assert "supports" in res["reason"]

    # F with H1000 - H1002
    res = dx_procedure_validator.validate_diagnosis_procedure("F10.2", "H1001")
    assert res["valid"] is True
    assert res["flagged"] is False
    assert "supports" in res["reason"]

    # F with normal E&M (99201-99215)
    res = dx_procedure_validator.validate_diagnosis_procedure("F32.9", "99213")
    assert res["valid"] is True
    assert res["flagged"] is False

def test_validate_diagnosis_procedure_invalid_f_chapter():
    # F with H0050 (out of range)
    res = dx_procedure_validator.validate_diagnosis_procedure("F10.2", "H0050")
    assert res["valid"] is False
    assert res["flagged"] is True
    assert "does not support" in res["reason"]

    # F with an invalid procedure (e.g. 10021 which is skin surgical)
    res = dx_procedure_validator.validate_diagnosis_procedure("F32.9", "10021")
    assert res["valid"] is False
    assert res["flagged"] is True

def test_validate_diagnosis_procedure_chapter_h():
    # H6-H9 is Otological, H0-H5 Ophthalmic
    # H60 (Otological) supports 69000
    res = dx_procedure_validator.validate_diagnosis_procedure("H60.3", "69000")
    assert res["valid"] is True
    assert res["flagged"] is False

    # H01 (Ophthalmic) does not support 69000
    res = dx_procedure_validator.validate_diagnosis_procedure("H01.0", "69000")
    assert res["valid"] is False
    assert res["flagged"] is True

    # H01 supports 65091 (Ophthalmic)
    res = dx_procedure_validator.validate_diagnosis_procedure("H01.0", "65091")
    assert res["valid"] is True
    assert res["flagged"] is False
