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
- **Node Categories**: Provider (NPI with address), Patient (ID with name), edges represent claims.
- **Detection Patterns**: Address collision (different providers at same physical address), geo-temporal leap (patient billed in different states same day), referral ring cycles (alternating patient-provider paths).
- **Relational Database Sync**: Dynamically populated from `ClaimProjections` and `ProviderProjections` tables. Graph is cached and invalidated after each claim audit so the next claim sees newly added edges.
- **Error Handling**: Fail-open — if graph analysis raises an exception, the claim is flagged for review rather than silently passed. Infrastructure failures should never hide potential fraud.

## See Also
[[Three-Tier AI Engine Overview]] · [[NetworkX Graph Construction]] · [[Dynamic Threshold Logic]]