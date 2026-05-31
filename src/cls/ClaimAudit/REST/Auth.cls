Class ClaimAudit.REST.Auth Extends %CSP.REST
{

/// SMART on FHIR OAuth2 token endpoint (password grant)
/// Accepts: { "grant_type": "password", "username": "...", "password": "...", "client_id": "...", "scope": "..." }
/// Returns: { "access_token": "...", "token_type": "bearer", "expires_in": 86400, "scope": "..." }
ClassMethod Login() As %Status
{
    Set tSC = $$$OK
    Try {
        Set tBody = ##class(%DynamicObject).%FromJSON(%request.Content)
        Set tGrantType = tBody.grant_type
        Set tUsername = tBody.username
        Set tPassword = tBody.password
        Set tClientId = tBody.client_id

        If tGrantType '= "password" {
            Set %response.Status = 400
            Write {"error": "unsupported_grant_type", "error_description": "Only password grant is supported"}.%ToJSON()
            Quit
        }
        If tUsername = "" || (tPassword = "") {
            Set %response.Status = 400
            Write {"error": "invalid_request", "error_description": "username and password required"}.%ToJSON()
            Quit
        }

        If '##class(Security.Users).Exists(tUsername) {
            Set %response.Status = 401
            Write {"error": "invalid_grant", "error_description": "Invalid credentials"}.%ToJSON()
            Quit
        }

        Set tValid = ##class(Security.Users).VerifyPassword(tUsername, pPassword)
        If 'tValid {
            Set %response.Status = 401
            Write {"error": "invalid_grant", "error_description": "Invalid credentials"}.%ToJSON()
            Quit
        }

        Set tToken = ..IssueSmartOnFHIRToken(tUsername, tClientId)
        If tToken = "" {
            Set %response.Status = 500
            Write {"error": "server_error", "error_description": "Failed to issue token"}.%ToJSON()
            Quit
        }

        Write {
            "access_token": (tToken),
            "token_type": "bearer",
            "expires_in": 86400,
            "scope": "launch patient/Patient.read patient/Condition.read user/Claim.read user/Claim.write user/ClaimResponse.read user/Task.read user/Task.write user/CommunicationRequest.read online_access fhirUser"
        }.%ToJSON()
    } Catch ex {
        Set tSC = ex.AsStatus()
        Write {"error": "server_error", "error_description": (ex.DisplayString())}.%ToJSON()
    }
    Quit tSC
}

/// OAuth2 token introspection endpoint (RFC 7662)
/// Accepts: { "token": "..." }
/// Returns: { "active": true/false, "sub": "...", "scope": "...", "exp": ..., ... }
ClassMethod Introspect() As %Status
{
    Set tSC = $$$OK
    Try {
        Set tBody = ##class(%DynamicObject).%FromJSON(%request.Content)
        Set tToken = tBody.token
        If tToken = "" {
            Set %response.Status = 400
            Write {"active": false}.%ToJSON()
            Quit
        }

        Set tResult = ..ValidateSMARTToken(tToken)
        Write tResult.%ToJSON()
    } Catch ex {
        Set tSC = ex.AsStatus()
        Write {"active": false}.%ToJSON()
    }
    Quit tSC
}

/// Issue a SMART on FHIR compliant JWT access token
ClassMethod IssueSmartOnFHIRToken(pUsername As %String, pClientId As %String = "claimaudit-ui") As %String [ Internal ]
{
    Try {
        Set tUserProps = ##class(Security.Users).Get(pUsername, .tProps)
        Set tFullName = $Get(tProps("FullName"), pUsername)
        Set tRoles = ##class(Security.Users).GetUserRoles(pUsername)

        Set tNow = $PIECE($HOROLOG, ",", 1)
        Set tHeader = {"alg": "HS256", "typ": "JWT"}
        Set tHeaderJson = tHeader.%ToJSON()
        Set tHeaderB64 = ..EncodeBase64Url(tHeaderJson)

        Set tPayload = {
            "sub": (pUsername),
            "iss": "https://claimauditai.com/fhir",
            "aud": (pClientId),
            "iat": (tNow),
            "exp": (tNow + 86400),
            "name": (tFullName),
            "fhirUser": ("Practitioner/" _ pUsername),
            "roles": (tRoles),
            "scope": "launch patient/Patient.read patient/Condition.read user/Claim.read user/Claim.write user/ClaimResponse.read user/Task.read user/Task.write fhirUser online_access"
        }
        Set tPayloadJson = tPayload.%ToJSON()
        Set tPayloadB64 = ..EncodeBase64Url(tPayloadJson)

        Set tSecret = ..GetOrCreateSecret()
        Set tSigningInput = tHeaderB64 _ "." _ tPayloadB64
        Set tSignature = $SYSTEM.Encryption.Base64Encode($SYSTEM.Encryption.HMACSHA256(tSigningInput, tSecret))
        Set tSignatureB64 = ..EncodeBase64Url(tSignature)

        Quit tHeaderB64 _ "." _ tPayloadB64 _ "." _ tSignatureB64
    } Catch ex {
        Quit ""
    }
}

/// Validate a SMART on FHIR JWT token. Returns introspection response per RFC 7662.
ClassMethod ValidateSMARTToken(pToken As %String) As %DynamicObject [ Internal ]
{
    Try {
        Set tParts = $LISTFROMSTRING(pToken, ".")
        If $LISTLENGTH(tParts) '= 3 Return {"active": false}

        Set tPayloadB64 = $LISTGET(tParts, 2)
        Set tPayloadJson = $SYSTEM.Encryption.Base64Decode(..PadBase64Url(tPayloadB64))
        Set tClaims = ##class(%DynamicObject).%FromJSON(tPayloadJson)

        Set tExp = +tClaims.exp
        If tExp = 0 Return {"active": false}
        If tExp < $PIECE($HOROLOG, ",", 1) Return {"active": false}

        If tClaims.iss '= "https://claimauditai.com/fhir" Return {"active": false}

        Set tUsername = tClaims.sub
        If tUsername = "" Return {"active": false}
        If '##class(Security.Users).Exists(tUsername) Return {"active": false}

        // Verify HMAC signature
        Set tHeaderPayload = $LISTGET(tParts, 1) _ "." _ tPayloadB64
        Set tSecret = ..GetOrCreateSecret()
        Set tComputedSig = $SYSTEM.Encryption.Base64Encode($SYSTEM.Encryption.HMACSHA256(tHeaderPayload, tSecret))
        Set tComputedSigB64 = ..EncodeBase64Url(tComputedSig)
        Set tProvidedSig = $LISTGET(tParts, 3)
        If tComputedSigB64 '= tProvidedSig Return {"active": false}

        Return {
            "active": true,
            "sub": (tClaims.sub),
            "scope": (tClaims.scope),
            "exp": (tClaims.exp),
            "iat": (tClaims.iat),
            "iss": (tClaims.iss),
            "fhirUser": (tClaims.fhirUser),
            "roles": (tClaims.roles)
        }
    } Catch ex {
        Return {"active": false}
    }
}

/// Middleware: validate Bearer token from Authorization header, optionally check role
/// Writes 401 error response and returns 0 on failure, 1 on success
ClassMethod RequireAuth(pRequiredRole As %String = "") As %Boolean
{
    Try {
        Set tAuthHeader = %request.GetCgiEnv("HTTP_AUTHORIZATION")
        If tAuthHeader = "" {
            Set tAuthHeader = %request.GetCgiEnv("Authorization")
        }
        If tAuthHeader = "" {
            Set %response.Status = 401
            Write {"error": "Authentication required. Include Authorization: Bearer <token>"}.%ToJSON()
            Return 0
        }
        If $EXTRACT(tAuthHeader, 1, 7) '= "Bearer " {
            Set %response.Status = 401
            Write {"error": "Invalid authorization scheme. Use: Bearer <token>"}.%ToJSON()
            Return 0
        }

        Set tToken = $EXTRACT(tAuthHeader, 8, *)
        Set tResult = ..ValidateSMARTToken(tToken)

        If 'tResult.active {
            Set %response.Status = 401
            Write {"error": "Invalid or expired token"}.%ToJSON()
            Return 0
        }

        // Role check
        If pRequiredRole '= "" {
            Set tUserRoles = $Get(tResult.roles)
            Set tHasRole = 0
            Set tIter = tUserRoles.%GetIterator()
            While tIter.%GetNext(.tKey, .tRole) {
                If tRole = pRequiredRole {
                    Set tHasRole = 1
                    Quit
                }
            }
            If 'tHasRole {
                Set %response.Status = 403
                Write {"error": ("Insufficient permissions. Required role: " _ pRequiredRole)}.%ToJSON()
                Return 0
            }
        }

        // Store current user info in process-private global for downstream use
        Set ^||ClaimAuditUser = tResult.sub
        Set ^||ClaimAuditUserFullName = tResult.name
        Set ^||ClaimAuditUserFHIRUser = tResult.fhirUser

        Return 1
    } Catch ex {
        Set %response.Status = 500
        Write {"error": ("Internal auth error: " _ ex.DisplayString())}.%ToJSON()
        Return 0
    }
}

/// Get current authenticated username
ClassMethod GetCurrentUser() As %String
{
    Quit $Get(^||ClaimAuditUser, "")
}

/// Get current authenticated user's full name
ClassMethod GetCurrentUserFullName() As %String
{
    Quit $Get(^||ClaimAuditUserFullName, "")
}

/// URL-safe Base64 encode helper
ClassMethod EncodeBase64Url(pStr As %String) As %String [ Internal ]
{
    Set tEncoded = $SYSTEM.Encryption.Base64Encode(pStr)
    Set tEncoded = $TRANSLATE(tEncoded, "+/", "-_")
    Set tEncoded = $REPLACE(tEncoded, "=", "")
    Quit tEncoded
}

/// Pad a URL-safe Base64 string for decoding
ClassMethod PadBase64Url(pStr As %String) As %String [ Internal ]
{
    Set tStr = $TRANSLATE(pStr, "-_", "+/")
    Set tPadding = 4 - ($LENGTH(tStr) # 4)
    If tPadding < 4 {
        For tI = 1:1:tPadding Set tStr = tStr _ "="
    }
    Quit tStr
}

/// Get or create the HMAC signing secret (stored in a system global, survives restarts)
ClassMethod GetOrCreateSecret() As %String [ Internal ]
{
    Set tSecret = $Get(^%SYS("ClaimAuditAI", "SMARTSecret"))
    If tSecret = "" {
        Set tSecret = $SYSTEM.Util.CreateGUID()
        Set ^%SYS("ClaimAuditAI", "SMARTSecret") = tSecret
    }
    Quit tSecret
}

}
