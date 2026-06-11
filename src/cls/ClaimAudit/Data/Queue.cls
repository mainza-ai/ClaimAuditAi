Class ClaimAudit.Data.Queue Extends (%Persistent, %XML.Adaptor, %JSON.Adaptor)
{

Property ClaimResponseId As %String [ Required ];

Property Status As %String [ Required ];

Property CreatedAt As %String [ Required ];

Property ProcessedAt As %String;

Property ErrorDetails As %String(MAXLEN = 16000);

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
            Quit tId.%Save()
        }
    }
    Set tQueue = ..%New()
    Set tQueue.ClaimResponseId = pClaimResponseId
    Set tQueue.Status = "pending"
    Set tQueue.CreatedAt = $Translate($ZDateTime($ZTIMESTAMP, 3, 1), " ", "T") _ "Z"
    Quit tQueue.%Save()
}

}
