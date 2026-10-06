import os
from pathlib import Path

from dotenv import load_dotenv
from sentence_transformers import SentenceTransformer
from sqlalchemy import create_engine, text


load_dotenv()


# ============================================================
# Configuration
# ============================================================

PROJECT_ROOT = Path(__file__).resolve().parent.parent

KNOWLEDGE_FILE = PROJECT_ROOT / "data" / "project_knowledge.md"

MODEL_NAME = "intfloat/multilingual-e5-small"


# ============================================================
# Database and embedding model
# ============================================================

engine = create_engine(
    os.getenv("VECTOR_DB_URL")
)

model = SentenceTransformer(
    MODEL_NAME
)


# ============================================================
# Read and split knowledge document
# ============================================================

document = KNOWLEDGE_FILE.read_text(
    encoding="utf-8"
)

chunks = [
    chunk.strip()
    for chunk in document.split("\n\n")
    if chunk.strip()
    and not chunk.strip().startswith("#")
]

source = KNOWLEDGE_FILE.name

print(f"Chunks found: {len(chunks)}")


# ============================================================
# Create embeddings
# ============================================================

passages = [
    "passage: " + chunk
    for chunk in chunks
]

embeddings = model.encode(passages)


# ============================================================
# Store chunks in pgvector
# ============================================================

insert_query = text("""
    INSERT INTO rag.chunks (
        source,
        content,
        embedding
    )
    VALUES (
        :source,
        :content,
        CAST(:embedding AS vector)
    );
""")


with engine.begin() as conn:

    # Remove the previous version of this document.
    conn.execute(
        text("""
            DELETE FROM rag.chunks
            WHERE source = :source;
        """),
        {"source": source}
    )

    for content, embedding in zip(
        chunks,
        embeddings
    ):
        embedding_string = (
            "["
            + ",".join(map(str, embedding))
            + "]"
        )

        conn.execute(
            insert_query,
            {
                "source": source,
                "content": content,
                "embedding": embedding_string,
            }
        )


print(
    f"Successfully ingested {len(chunks)} chunks "
    f"from {source}."
)