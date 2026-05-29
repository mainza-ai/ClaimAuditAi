# Embedded Python in IRIS

> Embedded Python allows the IRIS database kernel to execute Python packages like PyTorch and NetworkX natively in the database process memory space.

Embedded Python eliminates the overhead of external API serialization and database connection pools. By using the system-level call-in interface, python modules can access database tables directly:

```python
import iris

# Execute a native SQL query directly in IRIS process memory
rs = iris.sql.exec("SELECT PatientId, NoteEmbedding FROM ClaimAudit.ClinicalNotes")
for row in rs:
    patient_id = row[0]
    embedding = row[1]
```

This database-native execution enables ClaimAuditAI to run PyTorch anomaly profiling and NetworkX graph checks directly within the FHIR server's transactional lifecycle.

## Key Details
- **Execution Space**: Native IRIS kernel memory space (no external socket overhead).
- **Package Access**: Python packages are installed directly into `/usr/irissys/mgr/python`.
- **Global Mapping Class**: `%SYS.Python`
- **Module Import Syntax**: `Set module = ##class(%SYS.Python).Import("module_name")`

## See Also
[[System Architecture Overview]] · [[Autoencoder Architecture]] · [[NetworkX Graph Construction]]