# NumPy and SciPy Dependency Conflicts

> During container build, startup, or unit tests, Python calls (such as NLP vectorization or ML model imports) fail with `AttributeError: module 'numpy' has no attribute 'long'`.

### Symptom
When initializing the container or running pytest, you see exceptions like:
```python
AttributeError: module 'numpy' has no attribute 'long'
```
or:
```
NLP pre-load skipped: <PYTHON EXCEPTION> 246 <class 'AttributeError'>: module 'numpy' has no attribute 'long' - Import
```

### Root Cause
This error occurs due to a dependency version mismatch between `numpy` and `scipy` caused by multiple independent `pip` installation steps:
1. `sentence-transformers` is installed in a separate `pip install` step in the `Dockerfile` to bypass IPM/ZPM activation constraints (`--only-binary=:all:`).
2. Without a version lock, pip installs the latest version of `scipy` (e.g., `1.18.0`), which requires NumPy >= 2.0.0.
3. Later, when the IPM package is loaded, it executes `pip install -r requirements.txt`, which has `numpy==1.26.4` pinned.
4. This downgrades NumPy to `1.26.4`, leaving the newly installed SciPy 1.18.0 broken because NumPy 1.26.4 lacks the types expected by SciPy 1.18.0 (specifically causing `numpy.long` attribute errors during import of `scipy.sparse`).

### Resolution
Ensure that `scipy` is explicitly pinned to a version compatible with NumPy 1.26.4 in both the Dockerfile and `requirements.txt`.
1. Add `scipy==1.17.1` (or another compatible version) to `requirements.txt`:
   ```text
   numpy==1.26.4
   scipy==1.17.1
   ```
2. Pin `scipy==1.17.1` in the Dockerfile `pip install sentence-transformers` command:
   ```dockerfile
   "/home/irisowner/.venvs/mcp-tools/bin/python" -m pip install sentence-transformers==2.7.0 scipy==1.17.1 --index-url https://download.pytorch.org/whl/cpu --extra-index-url https://pypi.org/simple --break-system-packages --target /usr/irissys/mgr/python
   ```

## See Also
[[Troubleshooting Overview]] · [[Container Startup Failures]] · [[Embedded Python Import Errors]]
