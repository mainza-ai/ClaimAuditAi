Class ClaimAudit.FHIR.Utils Extends %RegisteredObject
{

/// Get the FHIR R4 service instance.
ClassMethod GetFHIRService() As HS.FHIRServer.Service
{
    Quit ##class(HS.FHIRServer.Service).EnsureInstance("/fhir/r4")
}

/// Read a FHIR resource by type and id.
/// Returns true on success and sets pJson to the response JSON.
ClassMethod ReadResource(pService As HS.FHIRServer.Service, pType As %String, pId As %String, Output pJson As %DynamicObject) As %Boolean
{
    Set pJson = ""
    Set tReq = ##class(HS.FHIRServer.API.Data.Request).%New()
    Set tReq.RequestMethod = "GET"
    Set tReq.RequestPath = "/" _ pType _ "/" _ pId
    Set tReq.Interaction = "read"
    Set tResp = ##class(HS.FHIRServer.API.Data.Response).%New()
    Do pService.DispatchRequest(tReq, .tResp)
    If '$IsObject(tResp.Json) Quit 0
    Set pJson = tResp.Json
    Quit 1
}

/// Update a FHIR resource via PUT.
/// Automatically sets resourceType and meta.lastUpdated.
/// Returns true on success, false on failure.
ClassMethod UpdateResource(pService As HS.FHIRServer.Service, pJson As %DynamicObject, pType As %String) As %Boolean
{
    Set pJson.resourceType = pType
    Set pJson.meta = $Select($IsObject(pJson.meta): pJson.meta, 1: {})
    Set pJson.meta.lastUpdated = ..FHIRTimestamp()
    Set tId = pJson.id
    If tId = "" Quit 0
    Set tReq = ##class(HS.FHIRServer.API.Data.Request).%New()
    Set tReq.RequestMethod = "PUT"
    Set tReq.RequestPath = "/" _ pType _ "/" _ tId
    Set tReq.Interaction = "update"
    Set tReq.Json = pJson
    Set tResp = ##class(HS.FHIRServer.API.Data.Response).%New()
    Do pService.DispatchRequest(tReq, .tResp)
    If $Extract(tResp.Status, 1) = "2" Quit 1
    Quit 0
}

/// Add or replace an extension by URL.
ClassMethod AddExtension(pJson As %DynamicObject, pUrl As %String, pValue) As %DynamicObject
{
    Set tExt = pJson.extension
    If '$IsObject(tExt) Set tExt = ##class(%DynamicArray).%New()
    Set tNewExt = ##class(%DynamicArray).%New()
    Set tIter = tExt.%GetIterator()
    While tIter.%GetNext(.tK, .tE) {
        If tE.url = pUrl Continue
        Do tNewExt.%Push(tE)
    }
    Set tObj = {"url": (pUrl)}
    If $IsObject(pValue) {
        Set tObj.valueString = pValue
    } Else {
        Set tObj.valueString = (pValue)
    }
    Do tNewExt.%Push(tObj)
    Set pJson.extension = tNewExt
    Quit pJson
}

/// Add standard authorizer extensions (authorized-by, rationale, decision-timestamp).
ClassMethod AddAuthorizerExtensions(pJson As %DynamicObject, pUser As %String, pRationale As %String) As %DynamicObject
{
    Do ..AddExtension(pJson, "https://claimauditai.com/fhir/extension/authorized-by", pUser)
    If pRationale '= "" {
        Do ..AddExtension(pJson, "https://claimauditai.com/fhir/extension/rationale", pRationale)
    }
    Do ..AddExtension(pJson, "https://claimauditai.com/fhir/extension/decision-timestamp", ..FHIRTimestamp())
    Quit pJson
}

/// Find a Task resource by claim reference.
/// Returns true and sets pJson, pId on success.
ClassMethod GetTaskByClaimId(pService As HS.FHIRServer.Service, pClaimId As %String, Output pJson As %DynamicObject, Output pTaskId As %String) As %Boolean
{
    Set pJson = ""
    Set pTaskId = ""
    Set tRS = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT Key FROM HSFHIR_X0001_S.Task WHERE focus = ?", "Claim/" _ pClaimId)
    If tRS.%Next() {
        Set tTaskKey = tRS.%Get("Key")
        Set pTaskId = $Piece(tTaskKey, "/", 2)
        If ..ReadResource(pService, "Task", pTaskId, .pJson) Quit 1
    }
    Quit 0
}

/// Return an ISO8601 timestamp string for the current UTC time (e.g., "2026-01-15T09:23:41.000Z").
ClassMethod FHIRTimestamp() As %String
{
    Set tDate = $ZDATE($PIECE($ZTIMESTAMP, ",", 1), 3)
    Set tTime = $ZTIME($PIECE($ZTIMESTAMP, ",", 2), 1)
    Quit tDate _ "T" _ tTime _ ".000Z"
}

}
