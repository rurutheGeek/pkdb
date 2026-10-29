# pkdb

ポケモンのデータを蓄える PostgreSQL スタックです。DB 本体に加えて、登録・閲覧用の
Web 画面（entry）、AI クライアント向けの MCP サーバ、DB 管理画面（Adminer）を
Docker Compose でまとめて動かします。テーブル定義・登録用の関数・権限は `sql/` に、
運用コマンドは `manage.py` にあります。

## 構成

- `compose.yaml` — db / adminer / entry / mcp の定義
- `compose.lock.yaml` — 上流イメージのダイジェスト固定（`manage.py lock` が更新）
- `db/` — DB のイメージ（`postgres:15.15-alpine` に pgvector を足す）
- `sql/` — スキーマ、登録用関数、ロールと権限、RAG の索引（`rag.sql`）
- `entry/` — 登録画面（Python / FastAPI）
- `mcp/` — MCP サーバ（Python）
- `manage.py` — 初期化・起動・ダンプ・復元・バックアップ

## ポケモンRAG（pgvector）

DB は `postgres:15.15-alpine` に pgvector を足したイメージを `db/Dockerfile` から組みます。基底イメージだけを `compose.yaml` の `build.args` でダイジェスト固定します。公式の `pgvector/pgvector` は Debian なので、libc が musl から glibc に変わり、テキストの照合順序（en_US.utf8）がずれるため使いません。

`sql/rag.sql` が `rag` スキーマと `rag.chunk`（`embedding vector(1024)`）、`pokemondb` を読むだけの `pkdb_rag` ロールを作ります。配備では `entry*.sql` のあとに流れ、何度流しても同じです。パスワードは `secrets/rag_password` に置き、`./manage.py entry-password` が設定します。

## 動かし方

Docker と Docker Compose のあるホストで、リポジトリの一番上から実行します。

```sh
./manage.py init     # .env・秘密値・保存先ディレクトリを作る
./manage.py lock     # 上流イメージをダイジェストで固定する
./manage.py up       # 起動する
```

`init` は `.env.example` を元に `.env` を作り、`secrets/` にパスワードを生成します。
生成済みの秘密値は作り直しません。`secrets/`・`backups/`・`.env` は Git に含めません。

```sh
./manage.py status                  # 状態を表示する
./manage.py backup --destination DIR  # DIR にバックアップを書く
./manage.py fetch --host HOST DIR   # 別サーバから DIR にダンプする
./manage.py restore DIR             # ダンプを復元する（既存 DB には触れない）
```

止めるときは `docker compose down` を使います。バックアップは既定で `backups/` に
書き、`--keep` で残す数を指定できます。

DB の接続先やポート、画面の公開 URL などは `.env` で設定します。値の一覧は
`.env.example` を参照してください。

## テスト

```sh
python3 -m pip install ruff pyyaml
ruff check --select E9,F .
python3 -m compileall -q manage.py entry mcp tests
python3 -m unittest discover -s tests
```

CI（`.github/workflows/ci.yml`）でも同じ lint・コンパイル・テストと、db / entry / mcp の
Docker イメージのビルドを行います。
