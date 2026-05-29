# FHIR SQL Builder Projection Gaps

> FHIR SQL Builder projection gaps occur when transactional resources fail transformation schemas, leaving projected SQL tables empty.

### Symptom
Our analytical engines fail because the projected SQL tables (`ClaimProjections`, `PatientProjections`) contain no records, despite having ingested FHIR resources.

### Diagnostic Steps
1. **Check Transformation Logs**: Check the FHIR SQL Builder task logs in the Management Portal under **Health** -> **FHIR Support** -> **FHIR SQL Builder**.
2. **Assert Resource Mappings**: Verify that your ingested FHIR resources contain all the fields required by your transformation mappings.

### Resolution
Update your ingested FHIR resource structures to ensure they conform to the mapped schemas, and re-run the transformation pipeline:
```bash
echo 'do ##class(ClaimAudit.AI.Engine).RebuildProjections()' | docker exec -i claimaudit-iris iris session IRIS -U INTEROP
```

## See Also
[[Troubleshooting Overview]] · [[FHIR SQL Builder Projections]] · [[Initialization Script]]