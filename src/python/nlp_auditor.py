import os
import sys
import threading
import numpy as np
from sentence_transformers import SentenceTransformer

# Try to import iris (only available within Embedded Python context)
try:
    import iris
except ImportError:
    iris = None

# Thread-safe model loader with locking
_model_instance = None
_model_lock = threading.Lock()

def get_model():
    global _model_instance
    if _model_instance is not None:
        return _model_instance

    with _model_lock:
        if _model_instance is not None:
            return _model_instance
        cache_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "model_cache")
        os.makedirs(cache_dir, exist_ok=True)
        os.environ["SENTENCE_TRANSFORMERS_HOME"] = cache_dir
        _model_instance = SentenceTransformer('all-MiniLM-L6-v2', cache_folder=cache_dir)
        return _model_instance

def vectorize_text(text: str) -> list:
    """Vectorize input text using SentenceTransformer and return as a flat float list."""
    if not text:
        return [0.0] * 384
    model = get_model()
    embeddings = model.encode(text)
    # Ensure it's a standard Python float list
    return [float(x) for x in embeddings]

def index_clinical_note(patient_id: str, doc_id: str, note_text: str) -> str:
    """Natively index unstructured clinical progress notes in the IRIS database."""
    if not iris:
        return "Not running inside InterSystems IRIS"
        
    try:
        # Generate high-dimensional embedding
        embedding_vec = vectorize_text(note_text)
        embedding_str = ",".join(map(str, embedding_vec))
        
        # Prepare dynamic SQL to insert embedding
        stmt = iris.sql.prepare(
            "INSERT OR UPDATE INTO ClaimAudit.ClinicalNotes (PatientId, DocumentReferenceId, DocumentText, Embedding) "
            "VALUES (?, ?, ?, TO_VECTOR(?, DOUBLE, 384))"
        )
        stmt.execute(patient_id, doc_id, note_text, embedding_str)
        return "OK"
    except Exception as e:
        sys.stderr.write(f"Error indexing clinical note: {str(e)}\n")
        return f"Error: {str(e)}"

def verify_clinical_validity(patient_id: str, code_description: str) -> dict:
    """Query high-dimensional embeddings using native VECTOR_COSINE search.
    
    Returns the maximum similarity score and the supporting textual evidence.
    """
    if not iris:
        return {"similarity": 1.0, "evidence": "Not running in IRIS context (mocked success)", "flagged": False}
        
    try:
        # Vectorize billed CPT / ICD-10 description
        query_vec = vectorize_text(code_description)
        query_str = ",".join(map(str, query_vec))
        
        # Prepare dynamic SQL query utilizing VECTOR_COSINE
        # Cosine similarity in IRIS is evaluated on high-dimensional float vectors
        # VECTOR_COSINE returns a double representing cosine similarity [-1 to 1]
        sql_query = (
            "SELECT TOP 3 DocumentText, VECTOR_COSINE(Embedding, TO_VECTOR(?, DOUBLE, 384)) AS Similarity "
            "FROM ClaimAudit.ClinicalNotes "
            "WHERE PatientId = ? "
            "ORDER BY Similarity DESC"
        )
        
        stmt = iris.sql.prepare(sql_query)
        rs = stmt.execute(query_str, patient_id)
        
        best_similarity = -1.0
        best_evidence = ""
        
        for row in rs:
            text = row[0]
            similarity = float(row[1])
            if similarity > best_similarity:
                best_similarity = similarity
                best_evidence = text
                
        # If no notes exist for this patient
        if best_similarity == -1.0:
            return {
                "similarity": 0.0,
                "evidence": "No clinical notes found for this patient in DocumentReference.",
                "flagged": True,
                "reason": "Missing supporting clinical documentation (phantom billing suspicion)."
            }
            
        # Evaluation threshold (standard semantic audit threshold is 0.38)
        flagged = best_similarity < 0.38
        reason = ""
        if flagged:
            reason = f"Procedural description lacks semantic alignment with progress notes (upcoding suspicion). Similarity: {best_similarity:.4f}"
            
        return {
            "similarity": best_similarity,
            "evidence": best_evidence,
            "flagged": flagged,
            "reason": reason
        }
        
    except Exception as e:
        sys.stderr.write(f"Error in verify_clinical_validity: {str(e)}\n")
        return {
            "similarity": 0.0,
            "evidence": f"Tier 1 NLP audit engine error: {str(e)}. Manual review required.",
            "flagged": True,
            "reason": f"NLP semantic audit failure: {str(e)}. Claim requires manual adjudication review."
        }
