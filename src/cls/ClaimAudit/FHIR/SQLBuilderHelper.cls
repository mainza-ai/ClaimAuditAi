Class ClaimAudit.FHIR.SQLBuilderHelper Extends %RegisteredObject
{

/// Query a pended claim and its risk score from FHIR SQL Builder projected tables
ClassMethod QuerySQLBuilderClaim(pClaimId As %String, Output pResult As %DynamicObject) As %Status
{
    Set pResult = {}
    Set tSC = $$$OK
    Try {
        // First check if the projected tables exist in the system
        Set tTablesExist = ..CheckProjectedTablesExist()
        If 'tTablesExist {
            Set pResult = {
                "success": false,
                "reason": "FHIR SQL Builder projections (FHIRSQL.Claim, FHIRSQL.ClaimResponse) have not been configured in the Management Portal GUI yet. Please import fhirsql/projections.json."
            }
            Quit
        }

        // Execute dynamic SQL against the projected tables
        Set tStatement = ##class(%SQL.Statement).%New()
        Set tSQL = "SELECT c.ClaimId, c.PatientReference, c.ProviderReference, c.TotalAmount, c.CreatedDate, "_
                   "       cr.ClaimResponseId, cr.Outcome, cr.Disposition, cr.RiskScore "_
                   "FROM FHIRSQL.Claim c "_
                   "LEFT JOIN FHIRSQL.ClaimResponse cr ON cr.ClaimReference = 'Claim/' || c.ClaimId "_
                   "WHERE c.ClaimId = ?"
        
        Set tSCPrep = tStatement.%Prepare(tSQL)
        If $$$ISERR(tSCPrep) {
            Set pResult = {"success": false, "reason": ("Query compilation failed: " _ $System.Status.GetErrorText(tSCPrep))}
            Quit
        }

        Set tRS = tStatement.%Execute(pClaimId)
        If tRS.%Next() {
            Set pResult = {
                "success": true,
                "claimId": (tRS.%Get("ClaimId")),
                "patient": (tRS.%Get("PatientReference")),
                "provider": (tRS.%Get("ProviderReference")),
                "amount": (+tRS.%Get("TotalAmount")),
                "created": (tRS.%Get("CreatedDate")),
                "responseId": (tRS.%Get("ClaimResponseId")),
                "outcome": (tRS.%Get("Outcome")),
                "disposition": (tRS.%Get("Disposition")),
                "riskScore": (+tRS.%Get("RiskScore"))
            }
        } Else {
            Set pResult = {"success": false, "reason": ("Claim not found in FHIR SQL Builder projections for ID: " _ pClaimId)}
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
        Set pResult = {"success": false, "reason": ("Exception during projection query: " _ ex.DisplayString())}
    }
    Quit tSC
}

/// Calculate overall statistics from the projected FHIR SQL Builder tables
ClassMethod GetProjectionStats(Output pStats As %DynamicObject) As %Status
{
    Set pStats = {}
    Set tSC = $$$OK
    Try {
        Set tTablesExist = ..CheckProjectedTablesExist()
        If 'tTablesExist {
            Set pStats = {
                "success": false,
                "reason": "Projections not configured."
            }
            Quit
        }

        Set tStatement = ##class(%SQL.Statement).%New()
        Set tSQL = "SELECT COUNT(*) as TotalClaims, COALESCE(SUM(TotalAmount), 0) as TotalValue FROM FHIRSQL.Claim"
        Set tSCPrep = tStatement.%Prepare(tSQL)
        If $$$ISOK(tSCPrep) {
            Set tRS = tStatement.%Execute()
            If tRS.%Next() {
                Set pStats.totalClaims = +tRS.%Get("TotalClaims")
                Set pStats.totalValue = +tRS.%Get("TotalValue")
            }
        }

        Set tSQL2 = "SELECT AVG(RiskScore) as AvgRisk FROM FHIRSQL.ClaimResponse WHERE RiskScore IS NOT NULL"
        Set tSCPrep2 = tStatement.%Prepare(tSQL2)
        If $$$ISOK(tSCPrep2) {
            Set tRS2 = tStatement.%Execute()
            If tRS2.%Next() {
                Set pStats.avgRiskScore = +tRS2.%Get("AvgRisk")
            }
        }
        Set pStats.success = 1
    } Catch ex {
        Set tSC = ex.AsStatus()
        Set pStats = {"success": false, "reason": (ex.DisplayString())}
    }
    Quit tSC
}

/// Helper to check if both FHIRSQL.Claim and FHIRSQL.ClaimResponse tables exist in the SQL catalog
ClassMethod CheckProjectedTablesExist() As %Boolean
{
    Set tExists = 0
    Try {
        Set tStatement = ##class(%SQL.Statement).%New()
        // Query InterSystems SQL Information Schema
        Set tSQL = "SELECT COUNT(*) as cnt FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'FHIRSQL' AND TABLE_NAME IN ('CLAIM', 'CLAIMRESPONSE')"
        Set tSC = tStatement.%Prepare(tSQL)
        If $$$ISOK(tSC) {
            Set tRS = tStatement.%Execute()
            If tRS.%Next() && (+tRS.%Get("cnt") = 2) {
                Set tExists = 1
            }
        }
    } Catch {
        Set tExists = 0
    }
    Quit tExists
}

}
