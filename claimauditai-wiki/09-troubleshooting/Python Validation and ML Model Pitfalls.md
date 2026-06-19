# Python Validation and ML Model Pitfalls

This page documents troubleshooting procedures for alphanumeric CPT/HCPCS code validations and autoencoder shape compatibility.

---

### 1. Alphanumeric CPT/HCPCS Code Validation TypeErrors
In the CMS NCCI-based validation rules, some CPT/HCPCS codes start with a letter (e.g. `H0001` or `H1000`).

#### Symptom
The Python backend throws a `NameError` (e.g. `NameError: name 'H0001' is not defined`) during startup, or a `TypeError` (e.g. `TypeError: '<=' not supported between instances of 'str' and 'int'`) when running a claim validation.

#### Root Cause
1. **NameError:** HCPCS codes (like `H0001`) written directly in code as literal integers without quotes are parsed as Python variables/identifiers instead of strings.
2. **TypeError:** Because CPT codes are parsed to integers by `_parse_cpt_code`, comparing an integer `cpt_num` to string bounds (like `"H0001"` and `"H0049"`) inside the rule engine (`cpt_low <= cpt_num <= cpt_high`) triggers a type mismatch.

#### Resolution
* **Quote rules as strings:** All alphanumeric codes in `_VALIDATION_RULES` must be enclosed in quotes:
  ```python
  ("F", "H0001", "H0049", "Alcohol and drug abuse treatment"),
  ```
* **Cast range bounds to integer:** Update the validation loop to dynamically convert range bounds to numeric values if they are strings:
  ```python
  low_num = _parse_cpt_code(cpt_low) if isinstance(cpt_low, str) else cpt_low
  high_num = _parse_cpt_code(cpt_high) if isinstance(cpt_high, str) else cpt_high
  if prefix_matched and low_num <= cpt_num <= high_num:
  ```

---

### 2. Autoencoder Shape Resiliency in Unit Tests
Upgrading the PyTorch autoencoder dimension (e.g. from 5 to 8 inputs) can cause existing unit tests with 5-column mock data to fail.

#### Symptom
Running `pytest` fails on `test_autoencoder_train.py` with `IndexError: index 7 is out of bounds for axis 1 with size 5` or `AssertionError: assert 'Successfully trained' in 'Error: list index out of range'`.

#### Root Cause
1. The unit tests pass mock claim feature arrays of shape `(N, 5)` to `normalize_features()`. The updated function checks index `7` (the 8th column, `provider_busyness`), causing an `IndexError`.
2. The mock SQL result sets in tests only have 5 columns, but `train_autoencoder()` tries to fetch `row[5]`, `row[6]`, and `row[7]` from the result iterator, causing an `IndexError: list index out of range`.

#### Resolution
* **Resilient `normalize_features`:** Inspect the input array shape (`features.shape[1]`) dynamically to only normalize indices that exist:
  ```python
  num_features = features.shape[1]
  continuous_indices = [0, 1, 3, 4]
  if num_features >= 8:
      continuous_indices.append(7)
  ```
* **Try-Except Guards on Row Fetches:** Wrap extra column fetches in try-except blocks, falling back to defaults if the index doesn't exist:
  ```python
  try:
      r_code_count = float(row[5])
  except Exception:
      r_code_count = r_items
  ```

---

## See Also
[[Troubleshooting Overview]] · [[Autoencoder Architecture]] · [[Diagnosis-Procedure Validator]]
