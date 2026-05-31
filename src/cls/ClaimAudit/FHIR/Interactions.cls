Class ClaimAudit.FHIR.Interactions Extends HS.FHIRServer.Storage.Json.Interactions
{

/// Intercept requests before they are processed by the storage engine
Method OnBeforeRequest(pFHIRService As HS.FHIRServer.API.Service, pFHIRRequest As HS.FHIRServer.API.Data.Request, pTimeout As %Integer)
{
    // Clean process private flag variables for this thread only for new Claim requests
    If (pFHIRRequest.Type = "Claim") || (pFHIRRequest.Type = "Bundle") {
        Kill ^||ClaimAuditFlag
    }
    
    // Intercept POST/PUT Claim creations (direct or inside Bundle entries)
    If $IsObject(pFHIRRequest.Json) {
        If pFHIRRequest.Type = "Claim" {
            Do ..AuditSingleClaim(pFHIRRequest.Json)
        } ElseIf (pFHIRRequest.Type = "Bundle") && $IsObject(pFHIRRequest.Json.entry) {
            Set tIter = pFHIRRequest.Json.entry.%GetIterator()
            While tIter.%GetNext(.tKey, .tEntry) {
                If $IsObject(tEntry.resource) && (tEntry.resource.resourceType = "Claim") {
                    Do ..AuditSingleClaim(tEntry.resource)
                }
            }
        }
    }
    
    // Continue standard interceptor processing

    Quit $$$OK
}

/// Run the three-tier audit engine on a single Claim JSON object and record flags
Method AuditSingleClaim(pClaimJson As %DynamicObject) [ Private ]
{
    Set tSC = ##class(ClaimAudit.AI.Engine).AuditClaim(pClaimJson, .tAuditResult)
    If tAuditResult.flagged = 1 {
        
        // Invoke AI Hub Agent to author explainable hold disposition
        Set summary = ##class(ClaimAudit.AI.Agent).GenerateHoldSummary(tAuditResult.patientId, tAuditResult.providerNpi, tAuditResult.billedAmount, tAuditResult.codeCount, tAuditResult.serviceDate, tAuditResult.firstCodeDesc, tAuditResult.reasons)
        
        // Record audit flags and summaries in thread-safe process memory
        Set ^||ClaimAuditFlag("flagged") = 1
        Set ^||ClaimAuditFlag("summary") = summary
        Set ^||ClaimAuditFlag("score") = tAuditResult.score

        // Store CPT/ICD from claim JSON so they can be embedded as ClaimResponse extensions
        // (Claims are not persisted by the interceptor, so we carry codes forward here)
        If $IsObject(pClaimJson.item) && (pClaimJson.item.%Size() > 0) {
            Set tItem = pClaimJson.item.%Get(0)
            If $IsObject(tItem.productOrService) && $IsObject(tItem.productOrService.coding) {
                Set tCoding = tItem.productOrService.coding.%Get(0)
                If tCoding '= "" {
                    Set ^||ClaimAuditFlag("cptCode") = tCoding.display
                    If ^||ClaimAuditFlag("cptCode") = "" Set ^||ClaimAuditFlag("cptCode") = tCoding.code
                }
            }
        }
        If $IsObject(pClaimJson.diagnosis) && (pClaimJson.diagnosis.%Size() > 0) {
            Set tDiag = pClaimJson.diagnosis.%Get(0)
            If $IsObject(tDiag.diagnosisCodeableConcept) && $IsObject(tDiag.diagnosisCodeableConcept.coding) {
                Set tDCoding = tDiag.diagnosisCodeableConcept.coding.%Get(0)
                If tDCoding '= "" Set ^||ClaimAuditFlag("icdCode") = tDCoding.code
            }
        }
    }
}

/// Intercept requests AFTER they have been processed by the storage engine
Method OnAfterRequest(pFHIRService As HS.FHIRServer.API.Service, pFHIRRequest As HS.FHIRServer.API.Data.Request, pFHIRResponse As HS.FHIRServer.API.Data.Response, pTimeout As %Integer)
{
    // Execute standard post-processing
    Do ##super(pFHIRService, pFHIRRequest, pFHIRResponse)
    
    Set ^ClaimAuditLog($HOROLOG, "type") = pFHIRRequest.Type
    Set ^ClaimAuditLog($HOROLOG, "status") = pFHIRResponse.Status
    Set ^ClaimAuditLog($HOROLOG, "isjson") = $IsObject(pFHIRRequest.Json)
    
    // Intercept POST/PUT DocumentReference creations to index progress notes
    If (pFHIRRequest.Type = "DocumentReference") && $IsObject(pFHIRRequest.Json) && ($Extract(pFHIRResponse.Status, 1) = "2") {
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
                    Set ^ClaimAuditIndexError($HOROLOG) = $System.Status.GetErrorText(tSC)
                }
            }
        } Catch ex {
            Set ^ClaimAuditIndexError($HOROLOG) = ex.DisplayString()
        }
    }

    // If the request was a Bundle, unpack and index any DocumentReference resources inside
    If $IsObject(pFHIRRequest.Json) && (pFHIRRequest.Json.resourceType = "Bundle") && ($Extract(pFHIRResponse.Status, 1) = "2") {
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
            // Retrieve summary and score from flags first, then clear flags to prevent infinite recursion
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

            // Transaction-safe creation of all 3 FHIR resources (ClaimResponse + Task + CommunicationRequest)
            TSTART

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
            If $IsObject(claimJson.total) {
                Set tTotalObj = {
                    "category": {"coding": [{"system": "http://terminology.hl7.org/CodeSystem/adjudication", "code": "submitted"}]},
                    "amount": (claimJson.total)
                }
                Set tTotalArr = ##class(%DynamicArray).%New()
                Do tTotalArr.%Push(tTotalObj)
                Set claimResponse.total = tTotalArr
            }

            // Embed CPT and ICD codes as extensions so they can be read without the Claim resource
            Set tExtensions = []
            Set tCptCode = $Get(^||ClaimAuditFlag("cptCode"))
            Set tIcdCode = $Get(^||ClaimAuditFlag("icdCode"))
            If tCptCode '= "" {
                Do tExtensions.%Push({"url": "https://claimauditai.com/fhir/extension/cpt-code", "valueString": (tCptCode)})
            }
            If tIcdCode '= "" {
                Do tExtensions.%Push({"url": "https://claimauditai.com/fhir/extension/icd-code", "valueString": (tIcdCode)})
            }
            If tExtensions.%Size() > 0 {
                Set claimResponse.extension = tExtensions
            }

            Set tRequestCR = ##class(HS.FHIRServer.API.Data.Request).%New()
            Set tRequestCR.RequestMethod = "POST"
            Set tRequestCR.Type = "ClaimResponse"
            Set tRequestCR.RequestPath = "ClaimResponse"
            Set tRequestCR.Interaction = "create"
            Set tRequestCR.Json = claimResponse
            Set tResponseCR = ##class(HS.FHIRServer.API.Data.Response).%New()
            Do pFHIRService.DispatchRequest(tRequestCR, .tResponseCR)

            If ($Extract(tResponseCR.Status, 1) '= "2") {
                Set ^ClaimAuditStatusLog($HOROLOG, "CR", "status") = tResponseCR.Status
                TROLLBACK
                Set pFHIRResponse.Status = 500
                Set pFHIRResponse.Json = {"error": "Failed to create ClaimResponse"}
                Kill ^||ClaimAuditFlag
                Quit
            }

            Set ^ClaimAuditStatusLog($HOROLOG, "CR", "status") = tResponseCR.Status
            Set ^ClaimAuditStatusLog($HOROLOG, "CR", "id") = tResponseCR.Id
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

            If ($Extract(tResponseT.Status, 1) '= "2") {
                Set ^ClaimAuditStatusLog($HOROLOG, "Task", "status") = tResponseT.Status
                TROLLBACK
                Set pFHIRResponse.Status = 500
                Set pFHIRResponse.Json = {"error": "Failed to create Task"}
                Kill ^||ClaimAuditFlag
                Quit
            }

            Set ^ClaimAuditStatusLog($HOROLOG, "Task", "status") = tResponseT.Status
            Set ^ClaimAuditStatusLog($HOROLOG, "Task", "id") = tResponseT.Id

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

            If ($Extract(tResponseComm.Status, 1) '= "2") {
                Set ^ClaimAuditStatusLog($HOROLOG, "Comm", "status") = tResponseComm.Status
                TROLLBACK
                Set pFHIRResponse.Status = 500
                Set pFHIRResponse.Json = {"error": "Failed to create CommunicationRequest"}
                Kill ^||ClaimAuditFlag
                Quit
            }

            TCOMMIT

            Set ^ClaimAuditStatusLog($HOROLOG, "Comm", "status") = tResponseComm.Status
            Set ^ClaimAuditStatusLog($HOROLOG, "Comm", "id") = tResponseComm.Id

            // Mutate outgoing response HTTP payload to return the queued ClaimResponse to submitting provider
            Set pFHIRResponse.Json = claimResponse
            Set pFHIRResponse.Status = 202

        } Catch ex {
            TROLLBACK
            Set ^ClaimAuditError($HOROLOG) = ex.DisplayString()
            Kill ^||ClaimAuditFlag
        }
    }
}

}
