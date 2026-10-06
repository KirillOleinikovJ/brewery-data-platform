import os

import requests
from dotenv import load_dotenv
from sentence_transformers import SentenceTransformer
from sqlalchemy import create_engine, text


load_dotenv()


# ============================================================
# Configuration
# ============================================================

VECTOR_DB_URL = os.getenv("VECTOR_DB_URL")
OLLAMA_URL = os.getenv("OLLAMA_URL")
OLLAMA_MODEL = os.getenv("OLLAMA_MODEL")

EMBEDDING_MODEL = "intfloat/multilingual-e5-small"
TOP_K = 3


if not VECTOR_DB_URL:
    raise ValueError("VECTOR_DB_URL is not configured")

if not OLLAMA_URL:
    raise ValueError("OLLAMA_URL is not configured")

if not OLLAMA_MODEL:
    raise ValueError("OLLAMA_MODEL is not configured")


# ============================================================
# Database and embedding model
# ============================================================

engine = create_engine(
    VECTOR_DB_URL
)

model = SentenceTransformer(
    EMBEDDING_MODEL
)


# ============================================================
# RAG service
# ============================================================

def answer_question(question: str):
    """
    Answer a question using semantic retrieval from pgvector
    and a local LLM running through Ollama.
    """

    # Convert the user question into an embedding.
    query_embedding = model.encode(
        "query: " + question
    )

    embedding_string = (
        "["
        + ",".join(map(str, query_embedding))
        + "]"
    )


    # Retrieve the most relevant knowledge chunks.
    query = text("""
        SELECT
            source,
            content,
            1 - (
                embedding <=> CAST(:embedding AS vector)
            ) AS similarity
        FROM rag.chunks
        ORDER BY
            embedding <=> CAST(:embedding AS vector)
        LIMIT :top_k;
    """)


    with engine.connect() as conn:
        result = conn.execute(
            query,
            {
                "embedding": embedding_string,
                "top_k": TOP_K,
            }
        )

        rows = result.mappings().all()


    # Combine retrieved chunks into a single context.
    context = "\n".join(
        row["content"]
        for row in rows
    )


    # Build the augmented prompt for the LLM.
    prompt = f"""
Du bist ein Assistent für ein Datenprojekt.

Beantworte die Frage ausschließlich anhand des folgenden Kontexts.

Wenn die Antwort nicht im Kontext enthalten ist, antworte:
"Diese Information ist im verfügbaren Kontext nicht enthalten."

Kontext:
{context}

Frage:
{question}

Antworte in einem vollständigen, kurzen Satz auf Deutsch.
"""


    # Generate the final answer with the local Qwen model.
    response = requests.post(
        OLLAMA_URL,
        json={
            "model": OLLAMA_MODEL,
            "prompt": prompt,
            "stream": False,
        },
        timeout=120,
    )

    response.raise_for_status()

    answer = response.json()["response"].strip()


    # Return the answer together with retrieval sources.
    sources = [
        {
            "source": row["source"],
            "content": row["content"],
            "similarity": round(
                float(row["similarity"]),
                3,
            ),
        }
        for row in rows
    ]

    return {
        "answer": answer,
        "sources": sources,
    }