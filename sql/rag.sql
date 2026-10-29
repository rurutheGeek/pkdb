-- ポケモンRAG の索引（pgvector）。
--
-- 図鑑説明・名前の由来・特性/わざの説明を埋め込みにして、pokemondb の構造化
-- データと同じ DB に置く。これで「タイプや世代で絞ってから意味で並べる」を
-- 1つの SQL で書ける（ハイブリッド検索）。
--
-- 何度流してもよい。entry*.sql のあと（最後）に流す。
-- 拡張の作成にはスーパーユーザー（postgres）が要る。

CREATE EXTENSION IF NOT EXISTS vector;
-- 名前の部分一致（ILIKE '%リザード%'）を速くする。日本語でも効く。
CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE SCHEMA IF NOT EXISTS rag;

-- 1行 = 1チャンク。本文は短い（図鑑説明は40〜120文字程度）ので分割しない。
-- pokedex は作品ごとに1行、origin は種族ごとに1行、ability/move は作品ごとに
-- 1行（説明文が同じでも出典の作品を残す）。
CREATE TABLE IF NOT EXISTS rag.chunk (
    chunk_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    kind text NOT NULL,
    -- 元の行を一意に決めるキー（例: pokedex:0211:01:0900）。
    source_key text NOT NULL,
    ndex_number varchar(4),
    form_id varchar(2),
    title_group_id varchar(3),
    body text NOT NULL,
    body_sha256 text NOT NULL,
    -- qwen3-embedding:0.6b の 1024 次元。変えるときはモデル名と一緒に移す。
    embedding vector(1024),
    embedding_model text,
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT chunk_kind CHECK (kind IN ('pokedex', 'origin', 'ability',
                                         'move', 'tag', 'wiki')),
    CONSTRAINT chunk_source UNIQUE (kind, source_key)
);

-- 既存の表にも wiki を足す（CREATE TABLE IF NOT EXISTS では制約が変わらない）。
ALTER TABLE rag.chunk DROP CONSTRAINT IF EXISTS chunk_kind;
ALTER TABLE rag.chunk ADD CONSTRAINT chunk_kind CHECK (kind IN ('pokedex', 'origin',
    'ability', 'move', 'tag', 'wiki'));

CREATE INDEX IF NOT EXISTS chunk_ndex ON rag.chunk (ndex_number);
CREATE INDEX IF NOT EXISTS chunk_kind_index ON rag.chunk (kind);
CREATE INDEX IF NOT EXISTS chunk_body_trgm ON rag.chunk USING gin (body gin_trgm_ops);

-- HNSW はまだ張らない。2万件程度なら全走査（正確）で数ms〜数十msに収まり、
-- 絞り込みとの相性もよい。件数が増えたら次を流し、recall と遅延を測ってから
-- 既定にする。
--   CREATE INDEX chunk_embedding ON rag.chunk
--       USING hnsw (embedding vector_cosine_ops) WITH (m = 16, ef_construction = 64);

-- RAG 用のロール。pokemondb は読むだけ、rag スキーマだけ書ける。
-- パスワードは apps-01 の secrets/rag_password にだけあり、manage.py が設定する。
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'pkdb_rag') THEN
    CREATE ROLE pkdb_rag LOGIN;
    RAISE NOTICE 'CHANGED: created role pkdb_rag';
  END IF;
END
$$;

GRANT USAGE ON SCHEMA pokemondb TO pkdb_rag;
GRANT SELECT ON ALL TABLES IN SCHEMA pokemondb TO pkdb_rag;
ALTER DEFAULT PRIVILEGES IN SCHEMA pokemondb GRANT SELECT ON TABLES TO pkdb_rag;

GRANT USAGE, CREATE ON SCHEMA rag TO pkdb_rag;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA rag TO pkdb_rag;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA rag TO pkdb_rag;
ALTER DEFAULT PRIVILEGES IN SCHEMA rag
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO pkdb_rag;
ALTER DEFAULT PRIVILEGES IN SCHEMA rag GRANT USAGE, SELECT ON SEQUENCES TO pkdb_rag;
