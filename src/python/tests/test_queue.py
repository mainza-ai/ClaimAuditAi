import pytest
import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

# Check if running inside IRIS container (meaning iris module is available)
try:
    import iris
    if not hasattr(iris, "cls"):
        iris = None
except ImportError:
    iris = None

@pytest.mark.skipif(iris is None, reason="Can only run inside InterSystems IRIS environment")
def test_iris_queue_dead_letter():
    claim_id = "test-dlq-claim-response-id"
    
    # Clean up any stale test records
    try:
        # Delete from Queue table via SQL
        stmt = iris.sql.prepare("DELETE FROM ClaimAudit_Data.Queue WHERE ClaimResponseId = ?")
        stmt.execute(claim_id)
    except Exception:
        pass

    # Call Queue ClassMethods via iris.cls
    queue_cls = iris.cls("ClaimAudit.Data.Queue")
    
    # 1. Enqueue
    status = queue_cls.Enqueue(claim_id)
    assert status == 1 or status is True

    # Retrieve the enqueued record using SQL
    stmt = iris.sql.prepare("SELECT ID, Status, RetryCount FROM ClaimAudit_Data.Queue WHERE ClaimResponseId = ?")
    rs = stmt.execute(claim_id)
    rows = list(rs)
    assert len(rows) == 1
    queue_id = rows[0][0]
    assert rows[0][1] == "pending"
    assert int(rows[0][2]) == 0

    # 2. Move to Dead Letter
    status = queue_cls.MoveToDeadLetter(queue_id, "Test error message")
    assert status == 1 or status is True

    # Verify status changed to dead-letter and error details updated
    stmt = iris.sql.prepare("SELECT Status, ErrorDetails FROM ClaimAudit_Data.Queue WHERE ID = ?")
    rs = stmt.execute(queue_id)
    rows = list(rs)
    assert len(rows) == 1
    assert rows[0][0] == "dead-letter"
    assert rows[0][1] == "Test error message"

    # 3. Requeue from Dead Letter
    status = queue_cls.RequeueFromDeadLetter(queue_id)
    assert status == 1 or status is True

    # Verify status changed back to pending, retry count reset
    stmt = iris.sql.prepare("SELECT Status, RetryCount, ErrorDetails FROM ClaimAudit_Data.Queue WHERE ID = ?")
    rs = stmt.execute(queue_id)
    rows = list(rs)
    assert len(rows) == 1
    assert rows[0][0] == "pending"
    assert int(rows[0][1]) == 0
    assert rows[0][2] == ""

    # Clean up
    stmt = iris.sql.prepare("DELETE FROM ClaimAudit_Data.Queue WHERE ID = ?")
    stmt.execute(queue_id)

@pytest.mark.skipif(iris is None, reason="Can only run inside InterSystems IRIS environment")
def test_iris_queue_list_and_clear():
    queue_cls = iris.cls("ClaimAudit.Data.Queue")
    claim_id_dl = "test-dl-query-id"
    
    try:
        stmt = iris.sql.prepare("DELETE FROM ClaimAudit_Data.Queue WHERE ClaimResponseId = ?")
        stmt.execute(claim_id_dl)
    except Exception:
        pass
        
    # Enqueue and move to dead-letter
    queue_cls.Enqueue(claim_id_dl)
    stmt = iris.sql.prepare("SELECT ID FROM ClaimAudit_Data.Queue WHERE ClaimResponseId = ?")
    rs = stmt.execute(claim_id_dl)
    rows = list(rs)
    queue_id = rows[0][0]
    queue_cls.MoveToDeadLetter(queue_id, "Some test error")
    
    # Test that it is retrieved in list query
    stmt = iris.sql.prepare("SELECT ID FROM ClaimAudit_Data.Queue WHERE Status = 'dead-letter'")
    rs_dl = stmt.execute()
    dl_ids = [r[0] for r in rs_dl]
    assert queue_id in dl_ids

    # Clean up
    stmt = iris.sql.prepare("DELETE FROM ClaimAudit_Data.Queue WHERE ID = ?")
    stmt.execute(queue_id)
