# Simulating Tier 3 - Collusion

> Collusion is simulated by submitting a claim containing a patient-provider relationship that completes a referral loop in our transaction graph.

To test the Tier 3 Collusion Network Mapper, we submit a claim with an entity profile that triggers our relational fraud flags:

```
Provider A ──(Claim)──> Patient A ──(Referral)──> Provider B ──(Address Link)──> Provider A
```

We test the engine by simulating:
1. **Referral Cycles**: Submitting multiple claims that create a circular pathway between Provider A, Patient A, and Provider B.
2. **Geo-Temporal Leaps**: Submitting two claims for the same patient at clinics 200 miles apart within a 3-hour window.

The NetworkX engine parses the active relationship graph, detects these structural anomalies, and flags the claim for collusion.

## Key Details
- **Relational Library**: NetworkX graph traversal.
- **Referral Loop Flag**: Triggered by simple cycles (`nx.simple_cycles`) in the referral graph.
- **Geo-Leap Distance Limit**: Geodetic distance conflicts > 150 miles per day.
- **Expected Action**: Immediate hold placement and audit trail resource persistence.

## See Also
[[Testing Overview]] · [[Tier 3 - Collusion Network Mapper]] · [[NetworkX Graph Construction]]