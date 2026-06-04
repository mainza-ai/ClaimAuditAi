# Security.Users.Validate Method Crash

> When calling `##class(Security.Users).Validate(username, password)` in InterSystems ObjectScript, the system throws a compile-time or runtime crash stating the method does not exist.

### Symptom

During credential authentication (e.g., in `/api/auth/login`), calling:
```objectscript
Set tIsValid = ##class(Security.Users).Validate(tUsername, tPassword)
```
results in an error:
```
<METHOD DOES NOT EXIST> *Validate^Security.Users
```
or a compilation failure because the class compiler cannot resolve `Validate` as a static classmethod on `Security.Users`.

### Root Cause

The `Security.Users` class in InterSystems IRIS does not provide a static classmethod called `Validate`. Instead, credential verification must be performed using instance-level verification methods on an opened user object.

### Resolution

To correctly validate a user's password:
1. Open the user instance using `%OpenId` in the `%SYS` namespace.
2. Invoke the instance method `CheckPassword` by reference, passing the password as the second argument.

```objectscript
// Correct Implementation:
zn "%SYS"
Set tUserObj = ##class(Security.Users).%OpenId(tUsername)
Set tIsValid = 0
If $IsObject(tUserObj) {
    Set tIsValid = ##class(Security.Users).CheckPassword(.tUserObj, tPassword)
}
zn "INTEROP"
```

> [!important]
> Since security and user accounts reside in the system namespace, you must switch namespace to `%SYS` (`zn "%SYS"`) before performing the user lookup and check, then switch back to the application namespace (e.g., `zn "INTEROP"`).

## See Also
[[IRIS Role-Based Access Control]] · [[Admin Routes Return 401]]
