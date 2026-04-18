---
name: rag-and-vector-search
description: "Use when building retrieval-augmented generation (RAG) pipelines, implementing vector search, choosing embedding models or vector databases, optimizing retrieval strategies, evaluating RAG quality (faithfulness, relevance, groundedness), or debugging RAG failures like hallucination, retrieval miss, or context overflow. Use for document chunking, hybrid search, reranking, context window optimization, and RAG evaluation with RAGAS or similar frameworks."
---

# RAG and Vector Search

Design, implement, and evaluate retrieval-augmented generation pipelines.

**Core principle:** Retrieval quality determines answer quality. A great generator with poor retrieval produces confident hallucinations.

## When to Use

- Building a question-answering system over documents
- Adding knowledge retrieval to an LLM application
- Implementing semantic search
- Evaluating or debugging an existing RAG pipeline
- Choosing between vector databases
- Optimizing retrieval relevance or reducing hallucination

## When NOT to Use

- Fine-tuning a model (RAG and fine-tuning are complementary, not substitutes)
- Simple keyword search (use Elasticsearch/Algolia)
- Real-time data that can't be pre-indexed (use function calling instead)

---

## Pipeline Architecture

```
INGESTION
  Documents → Clean → Chunk → Embed → Store in vector DB

RETRIEVAL  
  Query → Embed → Similarity Search → Rerank → Select Context

GENERATION
  Context + Query → LLM → Answer
```

---

## Document Chunking

### Strategy Selection

| Strategy | When to Use | Trade-offs |
|---------|-------------|-----------|
| **Fixed-size** (512-1024 tokens, 10-20% overlap) | Uniform documents, low latency required | May break semantic units |
| **Semantic** (split on topic shifts) | Long-form content, technical docs | Expensive, variable sizes |
| **Hierarchical** (paragraphs → sections → doc) | Complex documents needing multi-scale retrieval | Complex implementation |
| **Structural** (respect headers, code blocks) | Markdown, HTML, code | Requires format parsing |

### Chunking Rules

- Always include metadata: source, section title, page number, document date
- Never split mid-sentence
- Maintain 10-20% overlap between consecutive chunks
- Test with 3+ strategies and measure retrieval precision before choosing

```python
def chunk_fixed(text: str, size=1024, overlap=100) -> list[str]:
    chunks, step = [], size - overlap
    for i in range(0, len(text), step):
        chunks.append(text[i:i+size])
    return chunks
```

---

## Embedding Model Selection

| Dimension | Speed | Quality | Best For |
|-----------|-------|---------|----------|
| 384 (all-MiniLM-L6-v2) | Very fast | Good | High-volume, latency-sensitive |
| 768 (all-mpnet-base-v2) | Balanced | Excellent | Most production apps |
| 1536 (OpenAI ada-002) | Moderate | Very high | Complex, nuanced domains |
| Domain-specific (BioBERT, CodeBERT) | Varies | Best for domain | Specialized content |

**Selection criteria:**
1. Latency requirement < 100ms → use fast model (MiniLM)
2. High precision needed → use larger model (mpnet, ada-002)
3. Specialized content → use domain-specific model
4. Self-hosted required → use open-source (MiniLM, mpnet)

---

## Vector Database Selection

| Database | Best For | Hosting | Key Feature |
|----------|----------|---------|-------------|
| **pgvector** | RDBMS-first, ACID needed, relational joins | Self-hosted (PostgreSQL) | Combine with SQL queries |
| **Chroma** | Prototyping, development | Embedded/local | Zero-config, easy start |
| **Qdrant** | High performance, resource-constrained | Self-hosted or cloud | Rust speed, payload filtering |
| **Weaviate** | Complex use cases, multi-modal | Self-hosted or cloud | GraphQL, auto-vectorization |
| **Pinecone** | Managed production, no ops burden | Fully managed | 99.99% SLA, simple API |

---

## Retrieval Strategies

### Dense (Semantic) Retrieval

```python
results = vector_db.query(
    query_embedding=embed(query),
    k=5,
    filter={"category": "orders"}  # metadata pre-filtering
)
```

Best for: semantic similarity, paraphrase matching, conceptual queries.

### Sparse (Keyword) Retrieval

BM25 or Elasticsearch. Best for: exact terminology, proper nouns, product codes.

### Hybrid Search (Recommended for Production)

Combine dense + sparse with Reciprocal Rank Fusion:

```python
dense_results = semantic_search(query, k=10)
sparse_results = bm25_search(query, k=10)
fused = reciprocal_rank_fusion([dense_results, sparse_results])
```

### Reranking (Two-Stage)

1. Retrieve k=20 candidates with fast dense search
2. Rerank with cross-encoder model (slower but more accurate)
3. Return top k=5

Use when: precision matters more than latency. Adds ~100-200ms.

### Query Transformation

| Technique | When | How |
|-----------|------|-----|
| **HyDE** | Query style ≠ document style | Generate hypothetical answer, embed that |
| **Multi-query** | Ambiguous or complex queries | Generate 3-5 variations, retrieve for each |
| **Step-back** | Specific queries needing broader context | "What is X?" → "What are things like X?" |

---

## Context Window Optimization

### Assembly Strategy

1. Rank chunks by relevance score (highest first)
2. Remove redundant chunks (>90% semantic overlap)
3. Fit within token budget (leave room for prompt + output)
4. Order: general context first, specific evidence last

### Context Compression

When too many relevant chunks exist:
- Summarize lower-ranked chunks (keep key facts, remove prose)
- Extract only relevant sentences from each chunk
- Set minimum relevance threshold (drop chunks below 0.7 similarity)

---

## RAG Evaluation

### Key Metrics

| Metric | Definition | Target |
|--------|------------|--------|
| **Context Relevance** | Retrieved chunks relevant to query | >0.80 |
| **Faithfulness** | Answer grounded in context (not hallucinated) | >0.90 |
| **Answer Relevance** | Answer addresses the original question | >0.85 |
| **Precision@K** | % of top-K chunks that are relevant | >0.70 |

### RAGAS Framework

```python
from ragas import evaluate
from ragas.metrics import faithfulness, answer_relevancy, context_precision

scores = evaluate(
    dataset=test_dataset,  # questions, contexts, answers, ground_truths
    metrics=[faithfulness, answer_relevancy, context_precision],
)
print(scores)  # faithfulness: 0.92, answer_relevancy: 0.88, ...
```

---

## Common Failure Modes

| Failure | Symptoms | Fix |
|---------|---------|-----|
| **Retrieval miss** | Correct answer exists but not retrieved | Lower similarity threshold, improve chunking, try hybrid search |
| **Hallucination** | Answer not supported by context | Add faithfulness guardrail, improve retrieval, add "only use provided context" instruction |
| **Context overflow** | Context exceeds token limit | Raise similarity threshold, compress context, reduce chunk size |
| **Irrelevant retrieval** | Chunks retrieved are off-topic | Improve chunking, add metadata filters, use reranking |
| **Slow latency** | RAG adds >1s to response | Cache embeddings, use faster model, reduce k, cache common queries |

---

## Common Mistakes

- Not testing multiple chunking strategies before choosing
- Using generic embedding model for specialized domain without benchmarking
- Single-stage dense retrieval only (missing keyword matches)
- No evaluation framework (can't measure quality improvements)
- No fallback when retrieval returns 0 results
- Caching responses without checking if underlying documents changed

## Verification Checklist

- [ ] Chunking strategy tested and retrieval precision >0.70
- [ ] Embedding model benchmarked for domain relevance
- [ ] Hybrid search implemented (dense + sparse)
- [ ] Reranking applied for high-precision use cases
- [ ] Faithfulness >0.90 on test set (no hallucination)
- [ ] Context relevance >0.80 on test set
- [ ] Token budget respected (context fits in window)
- [ ] Fallback for empty retrieval results
- [ ] Latency <500ms end-to-end (retrieval + generation)
- [ ] Evaluation metrics monitored in production
