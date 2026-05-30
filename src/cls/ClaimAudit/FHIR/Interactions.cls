Class ClaimAudit.FHIR.Interactions Extends HS.FHIRServer.Storage.Json.Interactions
{

/// Intercept requests before they are processed by the storage engine
Method OnBeforeRequest(pFHIRService As HS.FHIRServer.API.Service, pFHIRRequest As HS.FHIRServer.API.Data.Request, pTimeout As %Integer)
{
    // Clean process private flag variables for this thread only for new Claim requests
    If pFHIRRequest.Type = "Claim" {
        Kill ^||ClaimAuditFlag
    }
    
    // Intercept POST/PUT Claim creations
    If (pFHIRRequest.Type = "Claim") && (pFHIRRequest.Json '= "") {
        Set claimJson = pFHIRRequest.Json
        
        // Execute dynamic audit engine checks (NLP, Autoencoder, Graph Tiers)
        Set tSC = ##class(ClaimAudit.AI.Engine).AuditClaim(claimJson, .tAuditResult)
        If $$$ISOK(tSC) && (tAuditResult.flagged = 1) {
            
            // Invoke AI Hub Agent to author explainable hold disposition
            Set summary = ##class(ClaimAudit.AI.Agent).GenerateHoldSummary(tAuditResult.patientId, tAuditResult.providerNpi, tAuditResult.billedAmount, tAuditResult.codeCount, tAuditResult.serviceDate, tAuditResult.firstCodeDesc, tAuditResult.reasons)
            
            // Record audit flags and summaries in thread-safe process memory
            Set ^||ClaimAuditFlag("flagged") = 1
            Set ^||ClaimAuditFlag("summary") = summary
            Set ^||ClaimAuditFlag("score") = tAuditResult.score
        }
    }
    
    // Continue standard interceptor processing
    Do ##super(pFHIRService, pFHIRRequest, pTimeout)
}

/// Mutate responses and create related audit trail records after the resource is committed
Method OnAfterRequest(pFHIRService As HS.FHIRServer.API.Service, pFHIRRequest As HS.FHIRServer.API.Data.Request, pFHIRResponse As HS.FHIRServer.API.Data.Response)
{
    // Execute standard post-processing
    Do ##super(pFHIRService, pFHIRRequest, pFHIRResponse)
    
    Set ^ClaimAuditLog("type") = pFHIRRequest.Type
    Set ^ClaimAuditLog("status") = pFHIRResponse.Status
    Set ^ClaimAuditLog("isjson") = (pFHIRRequest.Json '= "")
    
    // Intercept POST/PUT DocumentReference creations to index progress notes
    If (pFHIRRequest.Type = "DocumentReference") && (pFHIRRequest.Json '= "") && ($Extract(pFHIRResponse.Status, 1) = "2") {
        Try {
            Set docId = pFHIRResponse.Id
            If docId = "" Set docId = $Piece(pFHIRResponse.ETag, "/", 1)
            
            Set docJson = pFHIRRequest.Json
            Set patientRef = ""
            If $IsObject(docJson.subject) {
                Set patientRef = docJson.subject.reference
            }
            Set patientId = $Piece(patientRef, "/", *)
            
            // Extract the base64 clinical note data
            Set base64Data = ""
            If $IsObject(docJson.content) && (docJson.content.%Size() > 0) {
                Set contentItem = docJson.content.%Get(0)
                If $IsObject(contentItem.attachment) {
                    Set base64Data = contentItem.attachment.data
                }
            }
            
            If (patientId '= "") && (docId '= "") && (base64Data '= "") {
                // Decode base64 note text
                Set decodedNote = $system.Encryption.Base64Decode(base64Data)
                
                // Index the note in the vector database
                Set tSC = ##class(ClaimAudit.AI.Engine).IndexNote(patientId, docId, decodedNote)
                If $$$ISERR(tSC) {
                    Set ^ClaimAuditIndexError = $System.Status.GetErrorText(tSC)
                }
            }
        } Catch ex {
            Set ^ClaimAuditIndexError = ex.DisplayString()
        }
    }
    
    // If the request was a Bundle, unpack and index any DocumentReference resources inside
    If (pFHIRRequest.Json '= "") && (pFHIRRequest.Json.resourceType = "Bundle") && ($Extract(pFHIRResponse.Status, 1) = "2") {
        Try {
            Set bundleJson = pFHIRRequest.Json
            If $IsObject(bundleJson.entry) {
                Set iter = bundleJson.entry.%GetIterator()
                While iter.%GetNext(.key, .entry) {
                    If $IsObject(entry.resource) && (entry.resource.resourceType = "DocumentReference") {
                        Set docJson = entry.resource
                        Set docId = docJson.id
                        If docId = "" {
                            If $IsObject(entry.request) && (entry.request.url '= "") {
                                Set docId = $Piece(entry.request.url, "/", *)
                            }
                        }
                        
                        Set patientRef = ""
                        If $IsObject(docJson.subject) {
                            Set patientRef = docJson.subject.reference
                        }
                        Set patientId = $Piece(patientRef, "/", *)
                        
                        Set base64Data = ""
                        If $IsObject(docJson.content) && (docJson.content.%Size() > 0) {
                            Set contentItem = docJson.content.%Get(0)
                            If $IsObject(contentItem.attachment) {
                                Set base64Data = contentItem.attachment.data
                            }
                        }
                        
                        If (patientId '= "") && (docId '= "") && (base64Data '= "") {
                            Set decodedNote = $system.Encryption.Base64Decode(base64Data)
                            Do ##class(ClaimAudit.AI.Engine).IndexNote(patientId, docId, decodedNote)
                        }
                    }
                }
            }
        } Catch ex {
            Set ^ClaimAuditIndexError = ex.DisplayString()
        }
    }
    
    // If claim was flagged as an anomaly, mutate response and save audit records
    If (pFHIRRequest.Type = "Claim") && ($Get(^||ClaimAuditFlag("flagged")) = 1) {
        Try {
            // Retrieve summary and score from flags first, then clear flags to prevent infinite recursion in internal ProcessRequest calls
            Set summary = $Get(^||ClaimAuditFlag("summary"))
            Set score = $Get(^||ClaimAuditFlag("score"))
            Kill ^||ClaimAuditFlag
            
            Set claimId = pFHIRResponse.Id
            If claimId = "" Set claimId = $Piece(pFHIRResponse.ETag, "/", 1)
            If claimId = "" Set claimId = pFHIRRequest.Json.id
            
            Set claimJson = pFHIRRequest.Json
            
            // Resolve Patient reference
            Set patientRef = ""
            If $IsObject(claimJson.patient) {
                Set patientRef = claimJson.patient
            } Else {
                Set patientRef = { "reference": "Patient/unknown" }
            }
            
            Set createdTime = $Translate($ZDateTime($Horolog, 3, 1), " ", "T") _ "Z"
            
            // Resolve Claim Type for ClaimResponse
            Set claimType = ""
            If $IsObject(claimJson.type) {
                Set claimType = claimJson.type
            } Else {
                Set claimType = {
                    "coding": [
                        {
                            "system": "http://terminology.hl7.org/CodeSystem/claim-type",
                            "code": "professional"
                        }
                    ]
                }
            }

            // 1. Create FHIR ClaimResponse resource with "outcome" = "queued" (PENDED/HOLD status)
            Set claimResponse = {
                "resourceType": "ClaimResponse",
                "status": "active",
                "use": "claim",
                "type": (claimType),
                "patient": (patientRef),
                "created": (createdTime),
                "insurer": { "reference": "Organization/claimaudit-payer" },
                "outcome": "queued",
                "disposition": (summary),
                "request": { "reference": ("Claim/" _ claimId) }
            }
            
            Set tRequestCR = ##class(HS.FHIRServer.API.Data.Request).%New()
            Set tRequestCR.RequestMethod = "POST"
            Set tRequestCR.Type = "ClaimResponse"
            Set tRequestCR.RequestPath = "ClaimResponse"
            Set tRequestCR.Interaction = "create"
            Set tRequestCR.Json = claimResponse
            Set tResponseCR = ##class(HS.FHIRServer.API.Data.Response).%New()
            Do pFHIRService.DispatchRequest(tRequestCR, .tResponseCR)
            
            Set ^ClaimAuditStatusLog("CR", "status") = tResponseCR.Status
            Set ^ClaimAuditStatusLog("CR", "id") = tResponseCR.Id
            If $IsObject(tResponseCR.Json) { Set ^ClaimAuditStatusLog("CR", "json") = tResponseCR.Json.%ToJSON() }
            Set claimResponseId = tResponseCR.Id
            
            // 2. Create FHIR Task resource to route to manual audit review queues
            Set auditTask = {
                "resourceType": "Task",
                "status": "ready",
                "intent": "order",
                "priority": "urgent",
                "code": {
                    "coding": [
                        {
                            "system": "http://hl7.org/fhir/CodeSystem/task-code",
                            "code": "review",
                            "display": "Claim Audit Review"
                        }
                    ]
                },
                "focus": { "reference": ("Claim/" _ claimId) },
                "owner": { "reference": "Practitioner/claimaudit-auditor" },
                "description": ("Adjudication Score: " _ score _ ". Risk Reasons: " _ summary)
            }
            
            Set tRequestT = ##class(HS.FHIRServer.API.Data.Request).%New()
            Set tRequestT.RequestMethod = "POST"
            Set tRequestT.Type = "Task"
            Set tRequestT.RequestPath = "Task"
            Set tRequestT.Interaction = "create"
            Set tRequestT.Json = auditTask
            Set tResponseT = ##class(HS.FHIRServer.API.Data.Response).%New()
            Do pFHIRService.DispatchRequest(tRequestT, .tResponseT)
            
            Set ^ClaimAuditStatusLog("Task", "status") = tResponseT.Status
            Set ^ClaimAuditStatusLog("Task", "id") = tResponseT.Id
            If $IsObject(tResponseT.Json) { Set ^ClaimAuditStatusLog("Task", "json") = tResponseT.Json.%ToJSON() }
            
            // 3. Create FHIR CommunicationRequest containing Hold Notification for Provider
            Set commRequest = {
                "resourceType": "CommunicationRequest",
                "status": "active",
                "category": [
                    {
                        "coding": [
                            {
                                "system": "http://terminology.hl7.org/CodeSystem/communication-category",
                                "code": "notification",
                                "display": "Claim Hold Notification"
                            }
                        ]
                    }
                ],
                "payload": [
                    {
                        "contentString": (summary)
                    }
                ],
                "about": [
                    { "reference": ("Claim/" _ claimId) },
                    { "reference": ("ClaimResponse/" _ claimResponseId) }
                ]
            }
            
            Set tRequestComm = ##class(HS.FHIRServer.API.Data.Request).%New()
            Set tRequestComm.RequestMethod = "POST"
            Set tRequestComm.Type = "CommunicationRequest"
            Set tRequestComm.RequestPath = "CommunicationRequest"
            Set tRequestComm.Interaction = "create"
            Set tRequestComm.Json = commRequest
            Set tResponseComm = ##class(HS.FHIRServer.API.Data.Response).%New()
            Do pFHIRService.DispatchRequest(tRequestComm, .tResponseComm)
            
            Set ^ClaimAuditStatusLog("Comm", "status") = tResponseComm.Status
            Set ^ClaimAuditStatusLog("Comm", "id") = tResponseComm.Id
            If $IsObject(tResponseComm.Json) { Set ^ClaimAuditStatusLog("Comm", "json") = tResponseComm.Json.%ToJSON() }
            
            // Mutate outgoing response HTTP payload to return the queued ClaimResponse to submitting provider
            Set pFHIRResponse.Json = claimResponse
            Set pFHIRResponse.Status = 202 // Accepted/Queued for Hold
            
        } Catch ex {
            // Write error to system logs to prevent crash, fallback to standard claim output
            Set ^ClaimAuditError = ex.DisplayString()
        }
        
        // Clean thread flags
        Kill ^||ClaimAuditFlag
    }
}

}
