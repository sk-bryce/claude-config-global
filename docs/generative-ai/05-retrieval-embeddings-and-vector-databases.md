---
audience: human
created: 2026-07-28
updated: 2026-08-31
---

# Chapter 5: Retrieval, Embeddings, and Vector Databases

## In short

- An embedding is a fixed-length list of numbers (a vector) produced by a model to represent the meaning of a piece of text, image, or audio, so that meaning can be compared mathematically instead of by matching exact words.
- Similarity between two embeddings is measured with cosine similarity, dot product, or Euclidean distance. At large scale, systems use approximate nearest neighbor (ANN) search instead of exact search, trading a small amount of accuracy for enormous speed gains.
- A vector database stores embeddings alongside metadata and provides ANN indexing, filtering, and often hybrid search (vector similarity plus keyword search); it exists because relational databases are not built for this access pattern.
- Retrieval-Augmented Generation (RAG) gives a model access to information outside its training data and context window, without retraining it, by retrieving relevant text at query time and inserting it into the prompt.
- RAG, long context, and fine-tuning are three distinct ways to give a model more information; each has different cost, latency, and freshness trade-offs (the full decision framework is in [Chapter 7](07-related-and-advanced-topics.md)).
- Retrieval is one of the most common tools an agent calls, and vector-backed retrieval is one of the most common ways to implement an agent's long-term memory (Chapters 3 and 4).

## 1. Embeddings

### 1.1 What an embedding is

An embedding is a vector, a fixed-length ordered list of floating-point numbers, produced by a model to represent the meaning of an input. The input can be a word, a sentence, a paragraph, an image, an audio clip, or a mix of these (a multimodal embedding). Instead of storing or comparing raw text, systems store and compare these numeric vectors.

The core property that makes embeddings useful: two inputs with similar meaning are mapped to vectors that are close together in the vector space, even if they share no words in common. For example, "the cat sat on the mat" and "a feline rested on the rug" use almost entirely different vocabulary but describe a similar scene, and a well-trained embedding model places their vectors near each other. A traditional keyword match would treat these two sentences as almost unrelated.

Concretely, an embedding is just an array of numbers. A call to an embedding API for two short pieces of text might return something like:

```
"Sample text 1" -> [-0.0131, 0.0198, 0.0044, ...]   (1024 numbers total)
"Sample text 2" -> [-0.0069, 0.0209, -0.0037, ...]  (1024 numbers total)
```

There is nothing human-readable about any individual number in the vector; the meaning only emerges from the vector's position relative to other vectors, which is why embeddings are always used through distance or similarity comparisons (section 2) rather than inspected directly.

Embeddings are used for:

- Semantic search: finding documents related to a query by meaning, not just shared words.
- Clustering and deduplication: grouping similar items together.
- Classification and anomaly detection: using vector distance as a signal.
- Recommendation: finding items similar to ones a user already liked.
- Retrieval for RAG: finding the passages most relevant to a question before generation (section 4).

### 1.2 How embedding models are trained and used, conceptually

An embedding model is typically a neural network (often a transformer, the same family of architecture that underlies most modern language models, covered in [Chapter 2](02-models-training-and-inference.md)) that has been trained or adapted specifically to produce a single fixed-length vector summarizing an entire input, rather than to generate new text token by token.

A common training approach is contrastive learning: the model is shown many examples of pairs that should be considered similar (for example, a search query and the passage that correctly answers it, or two paraphrases of the same sentence) and pairs that should be considered dissimilar. Training adjusts the model's parameters so that embeddings of similar pairs are pulled closer together in the vector space and embeddings of dissimilar pairs are pushed further apart. Over many millions of such examples, the model learns a general-purpose geometry in which semantic relationships are reflected as spatial relationships.

In use, this training is invisible: a caller sends text to an embedding endpoint (or runs a local embedding model) and receives back a vector. That vector can be cached, stored, indexed, and compared, but it is not further modified. All of the "learning" happened once, offline, during the model's training; using the model afterward is a single forward pass with no further parameter updates.

### 1.3 Why semantically similar content ends up with similar vectors

The similarity in vector space is not a coincidence or metadata attached after the fact, it is a direct consequence of how the model was trained. Because the training objective explicitly rewards placing related content close together and unrelated content far apart, the internal representation the model builds up, layer by layer, comes to encode meaning as position and direction in a high-dimensional space. Words, phrases, or images that tend to appear in similar contexts, or that a training signal marked as semantically related, end up on nearby "regions" of that space.

This is why embeddings can capture relationships that keyword matching cannot: synonyms, paraphrases, related concepts, cross-lingual equivalents (for models trained multilingually), and even some analogical relationships fall out of the geometry the training process induced, rather than being programmed in explicitly. The best-known illustration comes from early word-embedding research: Mikolov et al.'s word2vec work found that the vector arithmetic "king" minus "man" plus "woman" lands closest to the vector for "queen," a relationship nobody programmed into the model but that emerged purely from training on word co-occurrence patterns.

### 1.4 Dimensionality, at a high level

The "dimensionality" of an embedding is simply how many numbers are in the vector. OpenAI's `text-embedding-3-small` produces 1536-dimensional vectors by default, and `text-embedding-3-large` produces 3072-dimensional vectors by default; Voyage AI's current-generation models default to 1024 dimensions. More dimensions generally allow a vector to capture more distinctions in meaning, at the cost of more storage and slower similarity computations.

Several current embedding models are trained with a technique (sometimes called Matryoshka representation learning) that lets a caller truncate a vector to a shorter length while mostly preserving its concept-representing properties, trading some accuracy for a smaller, faster-to-search vector. OpenAI exposes this as a `dimensions` parameter on its embeddings API, and Voyage AI's models similarly support several output dimension sizes on the same model. This flexibility matters in practice because many vector databases and index types have their own performance and memory trade-offs at different vector sizes, so being able to shorten an embedding without switching models is useful.

There is no universal "correct" dimensionality; it is a design choice made by whoever trained the model, balancing representational capacity against storage and compute cost. A few widely used models, for reference:

| Model | Provider | Default dimensions | Adjustable? |
| --- | --- | --- | --- |
| `text-embedding-3-small` | OpenAI | 1536 | Yes, via the `dimensions` parameter |
| `text-embedding-3-large` | OpenAI | 3072 | Yes, via the `dimensions` parameter |
| `voyage-4` | Voyage AI (recommended by Anthropic) | 1024 | Yes, supports 256, 512, 1024, or 2048 |

The adjustability matters in practice more than the raw numbers: a caller can pick a smaller vector size from the same model to save on storage and search latency, accepting a small accuracy cost, without switching to an entirely different, weaker model.

### 1.5 Embedding models versus generative or chat models

Embedding models and generative (chat, completion) models are often built on similar underlying architectures, but they are trained for different objectives and used differently:

| | Embedding model | Generative or chat model |
| --- | --- | --- |
| Output | A single fixed-length vector of numbers | A sequence of new tokens (text, code, etc.) |
| Purpose | Represent meaning for comparison, search, or clustering | Produce novel content, answer questions, follow instructions |
| Typical call pattern | One input in, one vector out, no back-and-forth | Often multi-turn, conversational, or agentic |
| Example use | "Find the 5 passages most similar to this query" | "Summarize this document" or "Write a function that does X" |
| Comparability of outputs | Outputs are directly comparable via distance/similarity math | Outputs are text; comparing two chat responses requires another model or a human judgment |

A practical illustration of this split: Anthropic does not offer its own embedding model at all. Its documentation directs developers to a dedicated embeddings provider (Voyage AI) for the retrieval side of a pipeline, while Claude itself remains the generative component that reads retrieved text and produces an answer. This is a common architecture: one specialized model (or provider) handles embeddings, and a separate generative model handles reasoning and text production, even within a single application.

### 1.6 Query embeddings, document embeddings, and domain-specific models

Retrieval is asymmetric: a search query is typically short ("what is our refund policy?") while the passages being searched are typically longer, self-contained pieces of text. Some embedding providers let, or require, a caller to indicate which role a given piece of text is playing. Voyage AI's API, for example, takes an `input_type` argument set to `"query"` or `"document"`, and its documentation notes this affects how the embedding is computed so that queries and the passages that should match them end up appropriately close in vector space, even though a question and its answer rarely share much vocabulary.

Embedding providers also increasingly offer models tuned for a specific domain rather than one general-purpose model for everything. Voyage AI's documentation lists separate models optimized for code retrieval, finance, and law, alongside its general-purpose and multilingual models, on the reasoning that vocabulary and notions of relevance differ enough between domains that a specialized model outperforms a general one for in-domain retrieval. Choosing a general-purpose versus a domain-specific embedding model is therefore a real design decision, not just a cost or latency trade-off.

### 1.7 Multimodal embeddings

Everything above describes text embeddings, but the same underlying idea, a model producing a fixed-length vector that captures meaning, applies to other modalities. A multimodal embedding model is trained so that text, images, and sometimes audio or video all land in the same shared vector space, meaning a text description and a matching image can end up with similar embeddings even though the raw inputs (text tokens versus pixel data) are completely different in form.

This is what makes it possible to search for images using a text query, or to search for text using an image as the query, without a separate translation step: both the query and the candidates are embedded into the same space, and similarity search (section 2) proceeds exactly as it would for two pieces of text. Voyage AI documents multimodal embedding models explicitly built to vectorize interleaved text, images, and, in its newer models, video, into one shared representation, and Google's own material on Vertex AI Vector Search describes combining text and image search in a single multimodal system. The vector database and ANN search machinery underneath is unchanged; only the embedding model at the front of the pipeline needs to understand multiple modalities.

## 2. Similarity Search

### 2.1 Measuring similarity between vectors

Once content is represented as vectors, "how similar are these two things" becomes a geometry question: how close are their vectors? Three measures dominate in practice.

**Cosine similarity** measures the angle between two vectors, ignoring their length (magnitude). It ranges from -1 (pointing in opposite directions) to 1 (pointing in exactly the same direction), with 0 meaning the vectors are orthogonal (unrelated in this measure). Cosine similarity is popular for text embeddings because it captures whether two vectors point the same "direction" in meaning-space regardless of how long the text was.

**Dot product** (inner product) multiplies corresponding elements of two vectors and sums the results. Unlike cosine similarity, the dot product is sensitive to vector length as well as angle. However, if vectors are normalized to unit length (length 1) before comparison, dot product and cosine similarity produce identical rankings, which is why many embedding providers normalize their output vectors. Anthropic's documentation notes explicitly that Voyage AI's embeddings (used by Claude, since Anthropic does not offer its own embedding model) are normalized to length 1, so "dot product and cosine similarity are the same" for those models.

**Euclidean distance** (L2 distance) measures the straight-line distance between the endpoints of two vectors, the same distance formula used for points in ordinary geometry. Smaller distance means more similar; unlike the two measures above, this is a distance (smaller is better) rather than a similarity score (larger is better).

A simplified illustration with 2-dimensional vectors (real embeddings have hundreds or thousands of dimensions, but the geometry generalizes):

```
Vector A ("dog"):    [0.90, 0.10]
Vector B ("puppy"):  [0.85, 0.20]
Vector C ("car"):    [0.05, 0.95]
```

- A and B point in nearly the same direction (both mostly along the first axis), so their cosine similarity is high and their Euclidean distance is small: the model considers "dog" and "puppy" closely related.
- A and C point in very different directions (one dominated by the first axis, one by the second), so their cosine similarity is low (closer to 0) and their Euclidean distance is large: the model considers "dog" and "car" unrelated.

Which measure to use in practice usually depends on how the embedding model was trained: most current text embedding models are trained and normalized so that cosine similarity (equivalently, dot product on normalized vectors) is the intended comparison, and vector databases such as pgvector expose cosine distance, inner product, and L2 distance as separate, explicitly chosen index and query operators rather than picking one automatically.

To make the arithmetic concrete, cosine similarity between two vectors a and b is the dot product of a and b divided by the product of their lengths. Using vectors A and B above:

```
dot(A, B)   = (0.90 * 0.85) + (0.10 * 0.20) = 0.765 + 0.020 = 0.785
length(A)   = sqrt(0.90^2 + 0.10^2) = sqrt(0.82)  ~ 0.906
length(B)   = sqrt(0.85^2 + 0.20^2) = sqrt(0.7625) ~ 0.873
cosine(A,B) = 0.785 / (0.906 * 0.873) ~ 0.785 / 0.791 ~ 0.99
```

A cosine similarity near 1.0 confirms what the geometry suggested visually: A ("dog") and B ("puppy") point in almost the same direction. Repeating the same calculation for A and C would produce a value much closer to 0, reflecting their near-orthogonal directions. This is the same computation a similarity search performs, just repeated against every candidate vector (exact search) or against a small subset chosen by an index (ANN search, section 2.3).

The three measures at a glance:

| Measure | What it captures | Sensitive to vector length? | Typical use |
| --- | --- | --- | --- |
| Cosine similarity | Angle between two vectors | No | Comparing text embeddings where only direction (meaning), not magnitude, should matter |
| Dot product | Angle and magnitude combined | Yes, unless vectors are pre-normalized | Fast comparison when embeddings are already normalized to unit length, common in modern embedding APIs |
| Euclidean (L2) distance | Straight-line distance between vector endpoints | Yes | General-purpose distance, common default in classic nearest-neighbor literature and some vector database defaults |

### 2.2 Why exact nearest neighbor search does not scale

Given a query vector, the naive way to find the most similar stored vectors is brute force: compute the similarity or distance between the query and every single stored vector, then sort. This is called exact nearest neighbor search, and it always finds the true best matches.

The problem is cost. Comparing one query vector against one stored vector of dimension d takes roughly d arithmetic operations. Comparing that query against n stored vectors takes roughly n times d operations. For a modest case of 1 million stored vectors at 1536 dimensions each, that is over 1.5 billion operations per single query. Real systems may hold hundreds of millions to billions of vectors and serve many queries per second; brute-force exact search at that scale becomes too slow and too expensive in compute to be practical, even though it would be perfectly accurate.

High dimensionality makes this worse in a second, less obvious way. Malkov and Yashunin's HNSW paper notes that exact search methods that work well in low-dimensional spaces (such as certain tree-based indexes) lose their advantage over brute force as dimensionality grows, a phenomenon widely known as the "curse of dimensionality": in high-dimensional spaces, the structure that lets an index skip over large portions of the data in low dimensions tends to break down, so exact indexing techniques stop offering a meaningful speedup right around the dimensionality that typical text and image embeddings actually use.

### 2.3 Approximate nearest neighbor (ANN) search

Approximate nearest neighbor (ANN) search accepts a small, controllable chance of missing the absolute best match in exchange for dramatically faster lookups, often orders of magnitude faster than brute force. Instead of comparing a query against every vector, an ANN algorithm builds an index, a data structure computed ahead of time, that lets a query be compared against only a small, well-chosen subset of vectors while still very likely finding the true nearest (or near-nearest) neighbors.

The quality of an ANN system is usually described in terms of recall: the percentage of the true nearest neighbors that the approximate search actually returns (Google's Vertex AI Vector Search documentation defines recall this way and gives a worked example: a query for 20 nearest neighbors that returns 19 correct ones has 95 percent recall). Nearly every ANN implementation exposes tunable parameters that let an operator move along a speed-versus-recall trade-off curve, accepting somewhat lower recall in exchange for lower latency, or vice versa.

Several families of ANN approach exist, distinguished by how they build their index. None is universally best; the right choice depends on how many vectors are stored, how much memory is available, whether the index is rebuilt frequently or mostly queried, and how much recall loss is acceptable for the application.

| Approach | How it works | Trade-off |
| --- | --- | --- |
| Graph-based (for example HNSW) | Connects each vector to a handful of its neighbors in a graph and searches by walking the graph toward the query, using a multi-layer structure (section 2.4) | Strong speed-versus-recall performance and works well as data is added incrementally, at the cost of higher memory use to store the graph |
| Clustering-based (for example IVF, inverted file index) | Partitions the vector space into clusters ahead of time and, at query time, only searches within the clusters closest to the query | Cheaper to build and often lower memory than graph-based methods, but can miss a true nearest neighbor sitting just across a cluster boundary |
| Quantization-based (for example product quantization) | Compresses each vector into a smaller approximate representation, for example replacing groups of floating-point numbers with a short code identifying the closest of a small set of pre-learned reference values, to speed up distance computation and cut memory use | Reduces memory and speeds up comparisons, but loses some precision per comparison; usually combined with a graph or clustering method rather than used alone |

Milvus's own documentation lists product quantization, HNSW, IVF, and DiskANN (a disk-resident graph index intended for datasets too large to fit in memory) side by side as index types it supports, precisely so operators can pick the combination that fits a given workload's memory, speed, and accuracy requirements rather than being locked into one approach.

Many systems also combine ANN with a second, exact step: retrieve a modest number of approximate candidates (for example the top 100) using the ANN index, then compute exact distances for just those candidates to produce the final ranked result. This "over-fetch and re-rank" pattern recovers some of the accuracy lost to approximation while still avoiding a full brute-force scan, since the expensive exact computation only runs over a small candidate set rather than the entire stored collection.

### 2.4 HNSW, conceptually

HNSW (Hierarchical Navigable Small World graphs) is one of the most widely deployed ANN algorithms and is used, in some form, by most of the vector databases discussed in section 3. Conceptually, without the underlying math:

- Every stored vector becomes a node in a graph, connected to a small number of other nodes that are close to it in the vector space.
- The graph is built in multiple layers. The top layer has very few nodes and long-range connections, letting a search jump across large regions of the space quickly. Lower layers have progressively more nodes and shorter, more local connections.
- A search starts at the top, sparse layer, greedily moves toward whichever neighboring node is closest to the query, and, once it can no longer improve within that layer, drops down to the next, denser layer to refine the search, repeating until it reaches the bottom layer.

The original HNSW paper by Malkov and Yashunin describes this as functioning similarly to a skip list (a data structure with multiple layers of shortcuts), and reports that the approach achieves logarithmic search complexity, meaning the number of comparisons needed grows very slowly as the number of stored vectors grows, which is what makes it practical at large scale. This is also why HNSW indexes are said to be "navigable": the multi-layer structure lets a search navigate toward the answer without ever inspecting most of the graph.

The practical trade-offs of HNSW (and ANN indexes generally) are: they use more memory and take longer to build than no index at all, they can occasionally return a near-miss instead of the true best match, and their accuracy versus speed can be tuned. Concretely, the original HNSW paper defines construction-time parameters such as `M` (how many connections each new element gets to its neighbors) and `efConstruction` (how wide a candidate list is considered while building the graph), and a query-time parameter `ef` (how wide a candidate list is considered while searching); raising these values generally improves recall at the cost of a larger index and slower construction or search. Most vector databases that implement HNSW, including pgvector and Qdrant, expose equivalent parameters under similar names for operators to tune.

## 3. Vector Databases

### 3.1 What they are, and why not just use a relational database

A vector database is a database designed around storing embeddings and finding the ones most similar to a given query vector, typically alongside conventional metadata about each item (source document, timestamp, tags, permissions, and so on).

A conventional relational database is optimized for exact-match and range queries over structured columns, using index structures like B-trees and hash indexes that assume there is a well-defined ordering or exact equality to index on. Vector similarity search does not fit that model: the question is not "give me rows where column X equals Y" but "give me the rows whose vector is closest to this other vector," which requires an entirely different indexing approach (the ANN structures described in section 2). This is why a class of purpose-built vector databases emerged, and why some conventional databases (notably Postgres, via the pgvector extension) added vector-specific index types rather than trying to answer these queries with existing indexes.

It is also worth distinguishing a vector database from a vector search library. Libraries such as FAISS (from Meta) or ScaNN (from Google) implement ANN algorithms and are what a vector database often runs internally, but a library alone does not persist data to disk with durability guarantees, replicate across nodes, support concurrent writes and reads, enforce access control, or let a caller filter by metadata as an integrated part of the search. Milvus's own documentation makes this distinction explicit, noting that its search engine builds on top of and outperforms popular ANN implementations like FAISS and HNSWLIB by adding the surrounding database engineering (hardware-aware optimization, a column-oriented storage engine, and a distributed, decoupled architecture) needed to run ANN search as a reliable, multi-tenant, production service rather than a single-process research tool.

### 3.2 Core capabilities

Across the products in this space, the recurring core capabilities are:

- **Vector storage with metadata.** Vectors are stored alongside structured fields (a document ID, category, permission tags, timestamps), so a query can retrieve both the vector match and the associated data in one round trip.
- **ANN indexing.** Built-in support for approximate nearest neighbor indexes (commonly HNSW, and often also IVF-style or disk-based variants) so similarity search scales past the point where brute force is viable.
- **Filtering.** The ability to restrict a similarity search to items matching metadata conditions, for example "find the closest passages, but only from documents this user is authorized to see." Qdrant's documentation notes that its filtering is integrated directly into the HNSW graph traversal itself (a "payload index" that extends the graph), rather than being applied as a separate pre- or post-processing pass, because naive pre- or post-filtering around an ANN index can silently reduce result quality.
- **Hybrid search.** Combining vector similarity with traditional keyword or lexical search, most commonly BM25 (a classic statistical keyword-ranking algorithm), so that exact terms, identifiers, or rare technical vocabulary that dense embeddings can under-represent are still matched reliably. Milvus, Qdrant, Weaviate, and Chroma all document explicit hybrid search support combining dense vectors, sparse or lexical signals, and reranking.

To make "vector storage with metadata" and "ANN indexing" concrete, pgvector's own documentation gives a minimal example of what these capabilities look like as ordinary SQL once the extension is enabled:

```sql
CREATE EXTENSION vector;
CREATE TABLE items (id bigserial PRIMARY KEY, embedding vector(3));
INSERT INTO items (embedding) VALUES ('[1,2,3]'), ('[4,5,6]');
SELECT * FROM items ORDER BY embedding <-> '[3,1,2]' LIMIT 5;
```

The `<->` operator computes Euclidean distance between the stored embedding and the query vector directly inside the `ORDER BY` clause (pgvector also defines `<#>` for negative inner product and `<=>` for cosine distance), and an HNSW or IVFFlat index on the `embedding` column, per the same documentation, is what turns that `ORDER BY` into an ANN lookup rather than a full table scan. Ordinary SQL features, `WHERE` clauses for filtering, joins to other tables, transactions, remain available on the same row.

### 3.3 Notable vector database options

The table below is a neutral summary based on each project's own documentation, not marketing claims. It is a snapshot of a fast-moving space; check current documentation before making an architecture decision.

| Option | Model | Description |
| --- | --- | --- |
| **Pinecone** | Managed cloud service | A managed, cloud-hosted vector database. Pinecone's own documentation describes it as "the vector database for AI agents and applications, built for semantic search, knowledge retrieval, and long-term memory at scale," with integrations for common agent frameworks and MCP-based tool access. |
| **Weaviate** | Open source, with managed cloud option | An open-source vector database that stores both data objects and their vector embeddings together, per its own documentation, supporting semantic search, hybrid (vector plus keyword) search, and RAG workflows. It can be self-hosted (Docker, Kubernetes, embedded) or run as the managed Weaviate Cloud. |
| **Milvus** | Open source, with managed cloud option (Zilliz Cloud) | An open-source, high-performance vector database built for large-scale deployment, from laptop-scale prototyping (Milvus Lite) up to distributed, Kubernetes-based clusters. Its own documentation describes support for multiple ANN index types (including HNSW, IVF, and DiskANN), metadata filtering, and native BM25-based full-text search alongside dense vector search. |
| **Qdrant** | Open source, with managed cloud/hybrid/private options | An open-source vector database and search engine with a client-server architecture, exposed over HTTP and gRPC. Qdrant's documentation emphasizes hybrid retrieval (dense plus sparse vectors), payload-based filtering integrated into its HNSW index, and a range of deployment models from self-hosted open source to fully managed cloud. |
| **Chroma** | Open source, with managed cloud option | An open-source project describing itself, in its own documentation, as "the open-source data infrastructure for AI," combining embedding storage, dense/sparse/hybrid search, and metadata filtering, usable locally, self-hosted, or via the managed Chroma Cloud. |
| **pgvector** | Open-source Postgres extension | An open-source extension that adds a vector data type and vector similarity operators (L2, inner product, cosine, L1, Hamming, and Jaccard distance, per its own documentation) directly to PostgreSQL, supporting both exact and approximate (HNSW and IVF-based) nearest neighbor search. Because it is a Postgres extension, vectors coexist with ordinary relational data and gain Postgres's transactional guarantees, joins, and existing operational tooling. |
| **Azure AI Search** | Managed cloud service (Microsoft Azure) | A managed search service that, per Microsoft's documentation, can be used as a vector index for long-term memory, knowledge bases, or RAG grounding data, supporting vector-only queries as well as hybrid vector-plus-keyword queries, with deep integration into other Azure AI and data platform services. |
| **Google Vertex AI Vector Search** | Managed cloud service (Google Cloud) | A managed vector search service built on Google's ScaNN similarity search algorithm, per Google's documentation, intended for large-scale semantic search, recommendation, and generative AI retrieval use cases, with support for dense, sparse, and hybrid search. |
| **Amazon OpenSearch Service (k-NN)** | Managed cloud service (AWS), open-source engine | A managed deployment of OpenSearch (an open-source search and analytics engine) with a k-nearest-neighbor (k-NN) feature that supports vector similarity search by Euclidean distance or cosine similarity, per AWS's documentation, alongside OpenSearch's existing full-text and log-analytics capabilities. It is one of several vector store options AWS supports for Bedrock Knowledge Bases. |

Notable pattern across the survey: most of these systems now converge on the same three capabilities (ANN indexing, metadata filtering, hybrid vector-plus-keyword search) regardless of whether they started as a dedicated vector database, an extension to an existing database, or a managed cloud search service. The meaningful differences between them tend to be about deployment model (self-hosted versus managed versus embedded), scaling characteristics, and how deeply they integrate with a particular cloud or application ecosystem, rather than about whether they support vector search at all.

### 3.4 Practical signals when narrowing this list

The survey above is deliberately neutral; narrowing it for a specific project usually comes down to a handful of practical questions rather than raw feature comparison, since most of these options now support the same core capabilities:

- **Do you already run Postgres?** If so, pgvector avoids introducing an entirely new system to operate, at the cost of being one extension among many rather than a system purpose-built around vector workloads from the ground up.
- **What operational model do you want?** Fully managed (Pinecone, Weaviate Cloud, Azure AI Search, Vertex AI Vector Search, Amazon OpenSearch Service) trades control and sometimes cost for not having to run the infrastructure yourself; self-hosted open source (Weaviate, Milvus, Qdrant, Chroma, all of which also offer this deployment mode per their own documentation) trades operational effort for control over infrastructure, data locality, and cost at scale.
- **What scale do you expect?** Prototyping or small corpora can run comfortably on an embedded or single-node setup (Chroma's local mode, Milvus Lite, a single pgvector-enabled Postgres instance); very large corpora (hundreds of millions to billions of vectors) push toward systems explicitly built for distributed, sharded deployment, such as Milvus's distributed mode or a managed cloud service.
- **Do you need hybrid search or just vector search?** If keyword precision on exact terms, IDs, or rare vocabulary matters, prioritize an option with documented native hybrid or BM25 support rather than adding a second, separate keyword search system to bolt on afterward.
- **Are you already committed to a cloud provider?** If a workload already lives on Azure, Google Cloud, or AWS, the corresponding cloud-native option (Azure AI Search, Vertex AI Vector Search, Amazon OpenSearch Service) usually reduces integration and networking overhead compared with introducing a separate third-party vector database.

## 4. Retrieval-Augmented Generation (RAG)

### 4.1 Why RAG exists

A generative model's knowledge is limited in two ways: it only knows what was present in its training data (which has a cutoff date and may not include private or proprietary information), and at inference time it can only reason over whatever fits in its context window ([Chapter 3](03-prompts-context-memory-and-caching.md)). Retraining a model to add new or private information is slow and expensive, and does not scale to information that changes frequently.

The original RAG paper, by Lewis et al., proposed combining a pretrained generative (parametric) model with a non-parametric memory, a retrievable index of documents, accessed by a trained retriever, so that the model could look up relevant information at generation time rather than relying solely on what was baked into its weights during training. The paper's framing is that this combination lets a model access and precisely manipulate knowledge, provide provenance for its outputs, and have its effective "knowledge" updated simply by updating the retrieval index rather than retraining the model. That combination, retrieve relevant text, then generate an answer conditioned on it, is what "RAG" now refers to broadly across the industry, well beyond the original paper's specific architecture.

### 4.2 The standard RAG pipeline

A typical RAG system has the following stages:

```
┌────────┐   ┌───────┐   ┌───────┐   ┌────────┐   ┌───────────┐   ┌─────────┐   ┌──────────┐
│ Ingest │ → │ Chunk │ → │ Embed │ → │ Store  │ → │ Retrieve  │ → │ Augment │ → │ Generate │
└────────┘   └───────┘   └───────┘   └────────┘   └───────────┘   └─────────┘   └──────────┘
```

1. **Ingest.** Pull in source documents: files, web pages, database records, tickets, and so on.
2. **Chunk.** Split each document into smaller passages (section 4.3), since embedding an entire long document as one vector loses too much specific detail to be useful for retrieval.
3. **Embed.** Convert each chunk into a vector using an embedding model (section 1).
4. **Store.** Save each chunk's vector plus its text and metadata in a vector database (section 3).
5. **Retrieve.** At query time, embed the user's question with the same embedding model, then run a similarity search against the stored vectors to find the most relevant chunks.
6. **Augment.** Insert the retrieved chunks into the prompt sent to the generative model, typically with instructions to answer using that provided context.
7. **Generate.** The generative model produces a response conditioned on both the original question and the retrieved context.

Worked through with a concrete example: a support team ingests its help-center articles (ingest), splits each article into paragraph-sized passages (chunk), and computes an embedding for each passage using an embedding model (embed), storing every passage's text, embedding, and source article ID in a vector database (store). A customer later asks a chatbot, "how do I get a refund on a subscription I canceled last month?" The system embeds that question with the same embedding model, searches the vector database for the passages whose embeddings are closest to it (retrieve), finds the two or three passages from the refund policy and cancellation articles, and inserts their text into the prompt sent to the generative model along with the customer's original question (augment). The model then answers using that specific, current policy text rather than whatever general knowledge about refunds it may have picked up during training (generate).

Many production RAG systems add an optional **reranking** step between retrieve and augment: a separate, typically smaller model re-scores the initial set of retrieved candidates for relevance to the specific query and reorders or trims them before they reach the prompt. This exists because ANN retrieval (section 2.3) is optimized for speed over a large corpus and can return candidates that are only loosely relevant; a reranker is cheaper to run over a short list of already-retrieved candidates than it would be to run over the whole corpus. Milvus's documentation lists reranking as a standard step in its search feature set, and Voyage AI documents dedicated reranking models (its `rerank-2.5` family) that take a query and a list of documents and return them reordered by relevance.

### 4.3 Chunking strategy, at a high level

How source documents are split into chunks materially affects retrieval quality, and there is no single correct answer:

- **Chunk size.** Chunks that are too small may lack enough surrounding context to be meaningful in isolation (a sentence fragment might match a query's keywords but not carry the information needed to answer it); chunks that are too large dilute the embedding (a vector representing many unrelated ideas is a poor match for a query about any single one of them) and can crowd out other relevant chunks once inserted into a limited context window.
- **Chunk overlap.** Adding some overlap between consecutive chunks reduces the risk that a piece of relevant information gets split awkwardly across a chunk boundary and is therefore poorly represented in either chunk's embedding.
- **Structure-aware chunking.** Splitting along natural document boundaries (headings, paragraphs, function or class definitions in code, table rows) generally produces more coherent chunks than splitting at a fixed number of characters or tokens without regard to structure. A fixed-size splitter applied to source code, for instance, can cut a function definition in half between its signature and its body, producing two chunks that are each individually much less useful to retrieve than the whole function would have been; a chunker aware of code structure would instead treat the function as a natural unit.
- **Metadata retention.** Retaining source, section title, and position metadata on each chunk supports both filtering (section 3.2) and giving the generative model enough provenance to cite or reason about where information came from.

These are judgment calls that depend on the type of content and the query patterns expected; the right choice for a codebase differs from the right choice for customer support transcripts or legal contracts.

### 4.4 RAG versus long context versus fine-tuning

RAG is one of three broad ways to give a model access to information it was not trained on or cannot otherwise reason about:

- **RAG (retrieval at query time):** the model's weights are unchanged; relevant text is retrieved and inserted into the prompt for that specific query. Information can be updated instantly by updating the index.
- **Long context (put everything in the prompt):** rather than retrieving a subset, some or all of a corpus is placed directly into the context window on every call, skipping the retrieval step entirely. This avoids retrieval-miss failures (section 4.5) but is more expensive and slower per call, and is still subject to how well the underlying model actually uses information spread across a long input. Liu et al.'s "Lost in the Middle" study found that model performance on finding and using relevant information degrades significantly when that information sits in the middle of a long context, rather than near the beginning or end, even for models explicitly designed for long contexts, meaning that simply fitting more text into the window does not guarantee the model will use it well.
- **Fine-tuning (change the weights):** additional training bakes information or behavior into the model itself. This changes what the model does by default without needing anything supplied at inference time, but it is slower and more expensive to update, is not well suited to information that changes frequently, and does not straightforwardly provide the citation or provenance benefits that retrieval does.

These three approaches are not mutually exclusive and are often combined in practice. [Chapter 7](07-related-and-advanced-topics.md) covers the full decision framework for choosing between fine-tuning, RAG, and prompting for a given problem; this chapter's purpose is only to establish that RAG is one point in that larger design space, not the only or automatically correct choice.

It is worth being explicit that RAG is not a free upgrade over simpler approaches. It introduces an entire additional system to build and operate (the ingestion pipeline and vector database of section 4.2), an additional network round trip and its associated latency on every query, and a new category of failure modes (section 4.5) that a purely prompted or fine-tuned system does not have. The justification for taking on that complexity is specific: access to information that is too large, too private, or too fast-changing to fit into either the model's training data or a single context window at an acceptable cost.

### 4.5 Common RAG failure modes

| Failure mode | What happens | Contributing factors | Typical mitigation |
| --- | --- | --- | --- |
| Retrieval miss | The chunk that actually contains the answer is never retrieved, so the model either fails or hallucinates an answer from its own training data | Poor chunking, a mismatch between how the query and the source documents are phrased, an embedding model not well suited to the domain, too small a value of k (number of chunks retrieved) | Tune chunking and k, add hybrid keyword search alongside vector search, evaluate and, if needed, switch to a more domain-appropriate embedding model |
| Irrelevant or excessive context | Retrieved chunks are topically related but do not answer the question, or too much text is stuffed into the prompt, and the model gets distracted or fails to use the one relevant passage effectively | Overly broad retrieval, no reranking step, and the general finding that models do not use all parts of a long context equally well, as documented by Liu et al. | Add a reranking step (section 4.2), retrieve fewer but higher-confidence chunks, place the most relevant chunk near the start or end of the prompt |
| Stale index | The vector database still reflects an older version of the source documents, so retrieval confidently returns outdated information | No re-ingestion pipeline triggered on document updates, embeddings not regenerated after switching embedding model versions, deleted source documents not removed from the index | Automate re-ingestion on source changes, or use a vector database with streaming/incremental update support (noted below) |

Guarding against a stale index is primarily an operational concern: the ingestion pipeline (section 4.2) needs to be re-run, or run continuously, whenever source content changes. Some managed vector search products document explicit support for streaming or incremental updates, for example Google's Vertex AI Vector Search, whose documentation describes a streaming update capability intended to let an index reflect newly inserted or changed vectors without a full index rebuild. Whether an index is rebuilt in batches on a schedule or updated continuously as documents change is itself a design decision that trades operational complexity against how current the retrieved information can be.

## 5. Where Retrieval Fits: Agent Memory and Tool Use

Retrieval, as described in this chapter, is a building block, not necessarily a standalone feature. Two places it commonly shows up elsewhere in this guide:

- **Agent memory ([Chapter 3](03-prompts-context-memory-and-caching.md)).** An agent's context window is finite and its conversation history does not persist between sessions by default. A common way to give an agent long-term or long-horizon memory is to embed and store important facts, past interactions, or documents in a vector database, then retrieve the relevant ones back into context when they become relevant again, rather than trying to keep everything in the context window at once.
- **Agentic tool use ([Chapter 4](04-agents-subagents-harnesses-and-tools.md)).** In an agentic system, retrieval is frequently exposed to the model as a callable tool (for example, a `search_documents` or `retrieve_context` function) rather than run as a fixed pipeline stage on every turn. This lets the agent itself decide when retrieval is needed, what to search for, and whether to retrieve again after seeing initial results, sometimes called "agentic RAG" as distinct from the fixed retrieve-then-generate pipeline described in section 4.2.

A vector database is, ultimately, a store of an organization's content, and often its sensitive content, converted into a different format. Access control over what a retrieval query is allowed to return (section 3.2's filtering capability), and where embedded data physically resides, are security and privacy questions in their own right; [Chapter 6](06-security-privacy-and-data.md) covers data security, privacy, and handling considerations that apply to retrieval systems alongside the rest of a generative AI stack.

Embedding, vector database, and RAG, three of the core terms introduced in this chapter, are also summarized in the glossary in [Appendix D](appendices/appendix-d-glossary-quick-reference.md) for quick lookup. Cosine similarity, ANN, HNSW, and chunking are explained inline above where each is first introduced, but do not have their own glossary entries; see the README's "Known gaps" section for details.

## References

### Official Documentation

- [Vector embeddings](https://developers.openai.com/api/docs/guides/embeddings) - OpenAI; what embeddings are, how to call the embeddings API, and the `dimensions` parameter for shortening vectors.
- [Embeddings](https://docs.anthropic.com/en/docs/build-with-claude/embeddings) - Anthropic; notes that Anthropic does not offer its own embedding model and documents Voyage AI's models, dimensions, and the normalization behind dot product versus cosine similarity.
- [Overview](https://qdrant.tech/documentation/overview/) - Qdrant; describes vector embeddings, sparse vectors, hybrid retrieval, and how payload filtering is integrated into its HNSW index.
- [Introduction](https://weaviate.io/developers/weaviate/introduction) - Weaviate; describes Weaviate's architecture, semantic and hybrid search, and deployment options.
- [What is Milvus?](https://milvus.io/docs/overview.md) - Milvus (Zilliz); describes Milvus's architecture, supported ANN index types (HNSW, IVF, DiskANN), and hybrid/full-text search via BM25.
- [Introduction](https://docs.trychroma.com/docs/overview/introduction) - Chroma; describes Chroma's storage, dense/sparse/hybrid search, and metadata filtering capabilities.
- [pgvector](https://github.com/pgvector/pgvector) - pgvector project; describes the Postgres extension's supported distance operators (L2, inner product, cosine, L1, Hamming, Jaccard) and its exact and approximate (HNSW, IVF) index types.
- [Pinecone documentation](https://docs.pinecone.io/guides/get-started/overview) - Pinecone; describes Pinecone as a managed vector database for semantic search, knowledge retrieval, and agent integrations.
- [Vector search overview](https://learn.microsoft.com/en-us/azure/search/vector-search-overview) - Microsoft; describes Azure AI Search's use as a vector index for RAG grounding data and knowledge bases, and its Azure AI platform integrations.
- [Vector Search](https://cloud.google.com/vertex-ai/docs/vector-search/overview) - Google Cloud; describes Vertex AI Vector Search, its use of the ScaNN algorithm, and dense/sparse/hybrid search support.
- [k-Nearest Neighbor (k-NN) search in Amazon OpenSearch Service](https://docs.aws.amazon.com/opensearch-service/latest/developerguide/knn.html) - AWS; describes OpenSearch's k-NN vector search feature, including Euclidean distance and cosine similarity options.

### Research

- [Retrieval-Augmented Generation for Knowledge-Intensive NLP Tasks](https://arxiv.org/abs/2005.11401) - Lewis et al. (2020); the original RAG paper combining a pretrained generative model with a retrievable non-parametric memory.
- [Efficient and robust approximate nearest neighbor search using Hierarchical Navigable Small World graphs](https://arxiv.org/abs/1603.09320) - Malkov and Yashunin; the paper introducing the HNSW algorithm and its multi-layer graph search approach.
- [Lost in the Middle: How Language Models Use Long Contexts](https://arxiv.org/abs/2307.03172) - Liu et al.; finds that model performance degrades when relevant information sits in the middle of a long context rather than near the beginning or end.
- [Linguistic Regularities in Continuous Space Word Representations](https://aclanthology.org/N13-1090.pdf) - Mikolov, Yih, and Zweig (2013); the paper originating the "king minus man plus woman equals queen" vector-arithmetic finding in word embeddings.

### Further Local Reading

- `03-prompts-context-memory-and-caching.md`, covers context windows and agent memory in depth.
- `04-agents-subagents-harnesses-and-tools.md`, covers agentic tool use, including retrieval exposed as a callable tool.
- `07-related-and-advanced-topics.md`, covers the full fine-tuning-versus-RAG-versus-prompting decision framework.
