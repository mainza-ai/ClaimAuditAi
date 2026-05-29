# Tier 3 - Collusion Network Mapper

> The Tier 3 engine models entity relationships using NetworkX directed graphs to detect provider fraud rings and referral collusion loops.

The mapper maintains a real-time transaction network where nodes represent NPI providers, referring doctors, patients, and clinic addresses, and edges represent financial claims:

```
Provider A ──(Claim)──> Patient A ──(Referral)──> Provider B ──(Address Link)──> Provider A
```

By traversing the active subgraph of the involved entities, the engine checks for collusion patterns, including:
1. **Referral Cycles**: Multi-provider referral loops designed to maximize patient billing.
2. **Geo-Temporal Leaps**: Claims submitted for the same patient at geographically distant clinics on the same day.
3. **Address Sharing**: Multiple disconnected provider NPIs operating out of the same residential location.

## Key Details
- **Library**: `networkx` running natively inside Embedded Python.
- **Node Categories**: Provider (NPI), Patient (ID), Doctor (ID), Address.
- **Relational Flag Criteria**: Geodetic distance conflicts > 150 miles per day; cyclic pathways in directed subgraphs.
- **Relational Database Sync**: Dynamically populated from projections on the `ClaimProjections` and `ProviderProjections` tables.

## See Also
[[Three-Tier AI Engine Overview]] · [[NetworkX Graph Construction]] · [[Dynamic Threshold Logic]]