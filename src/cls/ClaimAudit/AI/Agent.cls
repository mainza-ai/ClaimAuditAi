Class ClaimAudit.AI.Agent Extends %RegisteredObject
{

/// Core method to generate a pended claim summary from our Embedded Python AI orchestrator
ClassMethod GenerateHoldSummary(patientId As %String, providerNpi As %String, billedAmount As %Double, codeCount As %Integer, serviceDate As %String, firstCodeDesc As %String, auditReasons As %DynamicArray) As %String
{
    Set summary = ""
    Try {
        // Set environment paths
        Do ##class(ClaimAudit.AI.Engine).ConfigurePythonPath()
        
        // Import Python orchestrator
        Set orchestrator = ##class(%SYS.Python).Import("agent_orchestrator")
        Set pyAgent = orchestrator.ClaimAuditAgent()
        
        // Convert dynamic array of reasons into a Python list
        Set jsonLib = ##class(%SYS.Python).Import("json")
        Set pyReasons = jsonLib.loads(auditReasons.%ToJSON())
        
        // Invoke LLM report authoring
        Set summary = ""_pyAgent."generate_hold_summary"(patientId, providerNpi, billedAmount, codeCount, serviceDate, firstCodeDesc, pyReasons)
        
    } Catch ex {
        Set summary = "Payment Integrity Adjudication HOLD Notification. " _
                      "This claim has been pended for manual review due to high threat index anomaly scores. " _
                      "Flagged Discrepancy Summaries: " _
                      "Adjudication engine encountered an internal exception: " _ ex.DisplayString()
    }
    Quit summary
}

}
