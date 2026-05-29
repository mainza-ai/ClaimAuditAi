Class ClaimAudit.FHIR.Interactions Extends HS.FHIRServer.Storage.Json.Interactions
{

/// Intercept requests before they are processed by the storage engine
Method OnBeforeRequest(pFHIRService As HS.FHIRServer.API.Service, pFHIRRequest As HS.FHIRServer.API.Data.Request, pTimeout As %Integer)
{
    // Clean process private flag variables for this thread
    Kill ^||ClaimAuditFlag
    
    // Intercept POST/PUT Claim creations
    If (pFHIRRequest.ResourceType = "Claim") && (pFHIRRequest.Json '= "") {
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
    
    // If claim was flagged as an anomaly, mutate response and save audit records
    If $Get(^||ClaimAuditFlag("flagged")) = 1 {
        Try {
            Set claimId = pFHIRResponse.Id
            If claimId = "" Set claimId = $Piece(pFHIRResponse.ETag, "/", 1)
            
            Set summary = ^||ClaimAuditFlag("summary")
            Set score = ^||ClaimAuditFlag("score")
            Set claimJson = pFHIRRequest.Json
            
            // Resolve Patient reference
            Set patientRef = ""
            If $IsObject(claimJson.patient) {
                Set patientRef = claimJson.patient
            } Else {
                Set patientRef = { "reference": "Patient/unknown" }
            }
            
            Set createdTime = $Translate($ZDateTime($Horolog, 3, 1), " ", "T") _ "Z"
            
            // 1. Create FHIR ClaimResponse resource with "outcome" = "queued" (PENDED/HOLD status)
            Set claimResponse = {
                "resourceType": "ClaimResponse",
                "status": "active",
                "use": "claim",
                "patient": (patientRef),
                "created": (createdTime),
                "insurer": { "reference": "Organization/claimaudit-payer" },
                "outcome": "queued",
                "disposition": (summary),
                "request": { "reference": ("Claim/" _ claimId) }
            }
            
            Set tRequestCR = ##class(HS.FHIRServer.API.Data.Request).%New()
            Set tRequestCR.RequestMethod = "POST"
            Set tRequestCR.ResourceType = "ClaimResponse"
            Set tRequestCR.Json = claimResponse
            Set tResponseCR = ##class(HS.FHIRServer.API.Data.Response).%New()
            Do pFHIRService.ProcessRequest(tRequestCR, .tResponseCR)
            
            Set claimResponseId = tResponseCR.Id
            
            // 2. Create FHIR Task resource to route to manual audit review queues
            Set auditTask = {
                "resourceType": "Task",
                "status": "ready",
                "intent": "order",
                "priority": "high",
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
            Set tRequestT.ResourceType = "Task"
            Set tRequestT.Json = auditTask
            Set tResponseT = ##class(HS.FHIRServer.API.Data.Response).%New()
            Do pFHIRService.ProcessRequest(tRequestT, .tResponseT)
            
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
            Set tRequestComm.ResourceType = "CommunicationRequest"
            Set tRequestComm.Json = commRequest
            Set tResponseComm = ##class(HS.FHIRServer.API.Data.Response).%New()
            Do pFHIRService.ProcessRequest(tRequestComm, .tResponseComm)
            
            // Mutate outgoing response HTTP payload to return the queued ClaimResponse to submitting provider
            Set pFHIRResponse.Json = claimResponse
            Set pFHIRResponse.Status = 202 // Accepted/Queued for Hold
            
        } Catch ex {
            // Write error to system logs to prevent crash, fallback to standard claim output
            Set ^||ClaimAuditError = ex.DisplayString()
        }
        
        // Clean thread flags
        Kill ^||ClaimAuditFlag
    }
}

}
