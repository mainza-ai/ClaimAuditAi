Class ClaimAudit.Data.Queue Extends (%Persistent, %XML.Adaptor, %JSON.Adaptor)
{

Property ClaimResponseId As %String [ Required ];

Property Status As %String [ Required ];

Property CreatedAt As %String [ Required ];

Property ProcessedAt As %String;

Property ErrorDetails As %String(MAXLEN = 16000);

Property RetryCount As %Integer [ InitialExpression = 0 ];

Property MaxRetries As %Integer [ InitialExpression = 3 ];

Index ClaimResponseIndex On ClaimResponseId [ Unique ];
Index StatusIndex On Status;

ClassMethod Enqueue(pClaimResponseId As %String) As %Status
{
    Set tExists = ..ClaimResponseIndexExists(pClaimResponseId)
    If tExists {
        Set tId = ..ClaimResponseIndexOpen(pClaimResponseId)
        If $IsObject(tId) {
            Set tId.Status = "pending"
            Set tId.CreatedAt = $Translate($ZDateTime($ZTIMESTAMP, 3, 1), " ", "T") _ "Z"
            Set tId.ProcessedAt = ""
            Set tId.ErrorDetails = ""
            Set tId.RetryCount = 0
            Quit tId.%Save()
        }
    }
    Set tQueue = ..%New()
    Set tQueue.ClaimResponseId = pClaimResponseId
    Set tQueue.Status = "pending"
    Set tQueue.CreatedAt = $Translate($ZDateTime($ZTIMESTAMP, 3, 1), " ", "T") _ "Z"
    Quit tQueue.%Save()
}

/// Move a failed queue item to dead letter state after exhausting retries
ClassMethod MoveToDeadLetter(pQueueId As %String, pError As %String) As %Status
{
    Set tId = ..%OpenId(pQueueId)
    If '$IsObject(tId) Quit $$$ERROR($$$GeneralError, "Queue item not found")
    Set tId.Status = "dead-letter"
    Set tId.ErrorDetails = pError
    Set tId.ProcessedAt = $Translate($ZDateTime($ZTIMESTAMP, 3, 1), " ", "T") _ "Z"
    Quit tId.%Save()
}

/// Requeue a dead-letter item for reprocessing
ClassMethod RequeueFromDeadLetter(pQueueId As %String) As %Status
{
    Set tId = ..%OpenId(pQueueId)
    If '$IsObject(tId) Quit $$$ERROR($$$GeneralError, "Queue item not found")
    If tId.Status '= "dead-letter" Quit $$$ERROR($$$GeneralError, "Item is not in dead letter state")
    Set tId.Status = "pending"
    Set tId.RetryCount = 0
    Set tId.ProcessedAt = ""
    Set tId.ErrorDetails = ""
    Quit tId.%Save()
}

Query ListDeadLetter() As %SQLQuery
{
    SELECT ID, ClaimResponseId, CreatedAt, ErrorDetails, RetryCount
    FROM ClaimAudit_Data.Queue
    WHERE Status = 'dead-letter'
    ORDER BY CreatedAt DESC
}

}

