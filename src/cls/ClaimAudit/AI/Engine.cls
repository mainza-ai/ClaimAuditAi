Class ClaimAudit.AI.Engine Extends %RegisteredObject
{

/// Set up the database tables and native HNSW vector index
ClassMethod Setup() As %Status
{
    Set sc = $$$OK
    Try {
        // Set Python environment paths
        Do ##class(ClaimAudit.AI.Engine).ConfigurePythonPath()

        // 1. Create the ClinicalNotes vector table
        Set tStatement = ##class(%SQL.Statement).%New()
        Set tSQL = "CREATE TABLE ClaimAudit.ClinicalNotes ("_
                   "PatientId VARCHAR(50) NOT NULL, "_
                   "DocumentReferenceId VARCHAR(50) NOT NULL, "_
                   "DocumentText VARCHAR(32000), "_
                   "Embedding VECTOR(DOUBLE, 384), "_
                   "PRIMARY KEY (PatientId, DocumentReferenceId))"
        Set tSC = tStatement.%Prepare(tSQL)
        If $$$ISOK(tSC) {
            Do tStatement.%Execute()
            Write "Created table ClaimAudit.ClinicalNotes.", !
        } Else {
            Write "Table ClaimAudit.ClinicalNotes already exists or skipped: ", $System.Status.GetErrorText(tSC), !
        }

        // 2. Create the HNSW index on the vector field
        Set tIndexSQL = "CREATE INDEX HNSWIndex ON ClaimAudit.ClinicalNotes (Embedding) "_
                        "AS %SQL.Index.HNSW(Distance='Cosine', M=16, efConstruct=200)"
        Set tSC = tStatement.%Prepare(tIndexSQL)
        If $$$ISOK(tSC) {
            Do tStatement.%Execute()
            Write "Created HNSW Vector Index on ClaimAudit.ClinicalNotes.", !
        } Else {
            Write "HNSW Vector Index already exists or skipped: ", $System.Status.GetErrorText(tSC), !
        }

        // 3. Create PatientProjections table for relational graphs
        Set tSQL = "CREATE TABLE ClaimAudit.PatientProjections ("_
                   "Key VARCHAR(50) PRIMARY KEY, "_
                   "Name VARCHAR(100))"
        Set tSC = tStatement.%Prepare(tSQL)
        If $$$ISOK(tSC) { Do tStatement.%Execute() }

        // 4. Create ProviderProjections table
        Set tSQL = "CREATE TABLE ClaimAudit.ProviderProjections ("_
                   "NPI VARCHAR(50) PRIMARY KEY, "_
                   "Name VARCHAR(100), "_
                   "AddressLine VARCHAR(200))"
        Set tSC = tStatement.%Prepare(tSQL)
        If $$$ISOK(tSC) { Do tStatement.%Execute() }

        // 5. Create ClaimProjections table
        Set tSQL = "CREATE TABLE ClaimAudit.ClaimProjections ("_
                   "PatientKey VARCHAR(50), "_
                   "ProviderNPI VARCHAR(50), "_
                   "BilledAmount DOUBLE, "_
                   "ItemCount INTEGER, "_
                   "SpecialtyCode INTEGER, "_
                   "PatientAge INTEGER, "_
                   "DurationDays INTEGER, "_
                   "ServiceDate VARCHAR(10))"
        Set tSC = tStatement.%Prepare(tSQL)
        If $$$ISOK(tSC) { Do tStatement.%Execute() }

        // Trigger PyTorch autoencoder training with default synthetic values initially
        Set trainResult = ##class(ClaimAudit.AI.Engine).TrainAutoencoder()
        Write "Autoencoder Model: ", trainResult, !

    } Catch ex {
        Set sc = ex.AsStatus()
        Write "Setup Error: ", ex.DisplayString(), !
    }
    Quit sc
}

/// Helper method to append custom Python path to sys.path
ClassMethod ConfigurePythonPath()
{
    Try {
        Set sys = ##class(%SYS.Python).Import("sys")
        Set devPath = "/home/irisowner/dev/src/python"
        If '(sys.path."__contains__"(devPath)) {
            Do sys.path.insert(0, devPath)
        }
    } Catch {}
}

/// Index a clinical progress note in the native vector table
ClassMethod IndexNote(pPatientId As %String, pDocId As %String, pNoteText As %String) As %Status
{
    Set sc = $$$OK
    Try {
        Do ..ConfigurePythonPath()
        Set nlp = ##class(%SYS.Python).Import("nlp_auditor")
        Set res = nlp."index_clinical_note"(pPatientId, pDocId, pNoteText)
        If $Extract(res, 1, 5) = "Error" {
            Set sc = $$$ERROR($$$GeneralError, res)
        }
    } Catch ex {
        Set sc = ex.AsStatus()
    }
    Quit sc
}

/// Trigger PyTorch autoencoder training
ClassMethod TrainAutoencoder() As %String
{
    Set res = ""
    Try {
        Do ..ConfigurePythonPath()
        Set ae = ##class(%SYS.Python).Import("autoencoder_train")
        Set res = ae."train_autoencoder"()
    } Catch ex {
        Set res = "Error: "_ex.DisplayString()
    }
    Quit res
}

/// Execute three-tiered payment integrity audit on intercepted Claims
ClassMethod AuditClaim(pClaimJson As %DynamicObject, Output pResult As %DynamicObject) As %Status
{
    Set sc = $$$OK
    Set pResult = {
        "flagged": 0,
        "score": 0.0,
        "reasons": []
    }
    Try {
        Do ..ConfigurePythonPath()
        
        // Extract basic features from Claim dynamic object
        Set patientId = ""
        If $IsObject(pClaimJson.patient) {
            Set patRef = pClaimJson.patient.reference
            Set patientId = $Piece(patRef, "/", *)
        }
        
        Set providerNpi = ""
        If $IsObject(pClaimJson.provider) {
            Set provRef = pClaimJson.provider.reference
            Set providerNpi = $Piece(provRef, "/", *)
        }
        
        Set billedAmount = 0.0
        If $IsObject(pClaimJson.total) {
            Set billedAmount = +pClaimJson.total.value
        }
        
        Set codeCount = 0
        Set firstCodeDesc = ""
        If $IsObject(pClaimJson.item) {
            Set iter = pClaimJson.item.%GetIterator()
            While iter.%GetNext(.key, .item) {
                Set codeCount = codeCount + 1
                If (firstCodeDesc = "") && $IsObject(item.productOrService) {
                    Set codingIter = item.productOrService.coding.%GetIterator()
                    If codingIter.%GetNext(.cKey, .coding) {
                        Set firstCodeDesc = coding.display
                        If firstCodeDesc = "" Set firstCodeDesc = coding.code
                    }
                }
            }
        }
        
        Set specialtyCode = 1 // Default specialty
        Set patientAge = 45 // Default age
        Set durationDays = 1 // Default duration
        Set serviceDate = $ZDate($Horolog, 3) // Current date YYYY-MM-DD
        
        // TIER 1: Semantic NLP Vector Search
        Set nlp = ##class(%SYS.Python).Import("nlp_auditor")
        Set pyT1 = nlp."verify_clinical_validity"(patientId, firstCodeDesc)
        Set t1Flagged = +pyT1."__getitem__"("flagged")
        Set t1Reason = pyT1."__getitem__"("reason")
        Set t1Sim = +pyT1."__getitem__"("similarity")
        
        // TIER 2: PyTorch Autoencoder Anomaly Score
        Set ae = ##class(%SYS.Python).Import("autoencoder_train")
        Set pyT2 = ae."evaluate_claim_anomaly"(billedAmount, codeCount, specialtyCode, patientAge, durationDays)
        Set t2Flagged = +pyT2."__getitem__"("flagged")
        Set t2Reason = pyT2."__getitem__"("reason")
        Set t2Loss = +pyT2."__getitem__"("loss")
        
        // TIER 3: NetworkX Collusion Network Check
        Set ga = ##class(%SYS.Python).Import("graph_analyzer")
        Set pyT3 = ga."check_collusion_network"(patientId, providerNpi, serviceDate)
        Set t3Flagged = +pyT3."__getitem__"("flagged")
        Set t3Reason = pyT3."__getitem__"("reason")
        
        // Synthesis & Risk Scoring
        Set score = 0.0
        Set flaggedCount = 0
        
        If t1Flagged {
            Set score = score + 0.35
            Set flaggedCount = flaggedCount + 1
            Do pResult.reasons.%Push("Tier 1 (NLP): " _ t1Reason)
        }
        If t2Flagged {
            Set score = score + 0.35
            Set flaggedCount = flaggedCount + 1
            Do pResult.reasons.%Push("Tier 2 (ML): " _ t2Reason)
        }
        If t3Flagged {
            Set score = score + 0.30
            Set flaggedCount = flaggedCount + 1
            Do pResult.reasons.%Push("Tier 3 (Graph): " _ t3Reason)
        }
        
        // Cap score at 1.0
        If score > 1.0 Set score = 1.0
        Set pResult.score = score
        
        // If threat score exceeds threshold, flag for hold
        If score >= 0.35 {
            Set pResult.flagged = 1
        }
        
        Set pResult.patientId = patientId
        Set pResult.providerNpi = providerNpi
        Set pResult.billedAmount = billedAmount
        Set pResult.codeCount = codeCount
        Set pResult.serviceDate = serviceDate
        Set pResult.firstCodeDesc = firstCodeDesc
        
    } Catch ex {
        Set sc = ex.AsStatus()
        Set pResult.flagged = 0
        Do pResult.reasons.%Push("Adjudication engine failed: " _ ex.DisplayString())
    }
    Quit sc
}

}
