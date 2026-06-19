# ObjectScript Logical Operators

> In MUMPS and ObjectScript, the legacy logical OR operator `!` is non-short-circuiting. Using it instead of the modern `||` operator is discouraged in class definitions as it does not short-circuit.

### Symptom
- Conditionally checked expressions do not short-circuit, potentially evaluating the right-hand operand even when the left-hand operand is already satisfied.
- This can lead to runtime errors (like `<NULL VALUE>` or `<OBJECT DISPATCH>`) when the right-hand side references a property or method of an object that was checked for existence on the left-hand side.
- Developers familiar with other languages may confuse `!` (often logical NOT in other languages) with logical OR, leading to severe logical bugs (e.g., writing `If (tUsername = "") ! (tPassword = "")` expecting it to mean logical NOT).

### Root Cause
1. **Operator Semantics:**
   - `||` is the modern short-circuiting logical OR.
   - `&&` is the modern short-circuiting logical AND.
   - `!` is the legacy non-short-circuiting logical OR.
   - `'` (apostrophe) is the logical NOT operator in ObjectScript.
2. **Evaluation Behavior:**
   - ObjectScript evaluates expressions strictly left-to-right.
   - When using `!`, both sides are always evaluated. For example:
     ```objectscript
     If '$IsObject(obj) ! (obj.Property = "")  // Will crash if obj is Null/empty!
     ```
   - When using `||`, the expression short-circuits safely:
     ```objectscript
     If '$IsObject(obj) || (obj.Property = "")  // Evaluates safely and doesn't crash
     ```

### Resolution
Always use the modern short-circuiting `||` and `&&` operators for logical evaluations in class methods:
```objectscript
// Avoid:
If (tUsername = "") ! (tPassword = "") { ... }

// Use:
If (tUsername = "") || (tPassword = "") { ... }
```

## See Also
[[Troubleshooting Overview]] · [[iris.script Indentation Pitfalls]]
