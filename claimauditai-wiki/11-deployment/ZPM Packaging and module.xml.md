# ZPM Packaging and module.xml

> The module.xml manifest configures the InterSystems Package Manager (ZPM) packaging, defining dependencies, classes, and automated setup hooks.

The package is configured using the [module.xml](file:///Users/mck/Desktop/claimauditai/module.xml) manifest, which defines our deployment settings:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Module>
  <Name>claim-audit-ai</Name>
  <Version>1.0.0</Version>
  <Description>Autonomous pre-payment payment integrity agent</Description>
  <SourcesRoot>src</SourcesRoot>
  <Resource Name="ClaimAudit.FHIR.RepoManager.cls"/>
  <Resource Name="ClaimAudit.FHIR.InteractionsStrategy.cls"/>
  <Resource Name="ClaimAudit.FHIR.Interactions.cls"/>
  <!-- Post-install setup hook -->
  <Invoke Class="ClaimAudit.AI.Engine" Method="Setup" Phase="post-install"/>
</Module>
```

The manifest includes a `post-install` hook that automatically triggers `##class(ClaimAudit.AI.Engine).Setup()`, which creates our projection tables, builds HNSW vector indexes, and trains the anomaly detection models.

## Key Details
- **ZPM Manifest File**: `module.xml`
- **Module Name**: `claim-audit-ai`
- **Post-Install Invoke Class**: `ClaimAudit.AI.Engine`
- **Post-Install Invoke Method**: `Setup`

## See Also
[[Deployment Overview]] · [[Initialization Script]] · [[Installation Guide]]