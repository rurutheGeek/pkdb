# pkdb

ポケモンのデータを蓄える PostgreSQL スタックです。DB 本体に加えて、登録・閲覧用の
Web 画面（entry）、AI クライアント向けの MCP サーバ、DB 管理画面（Adminer）を
Docker Compose でまとめて動かします。テーブル定義・登録用の関数・権限は `sql/` に、
運用コマンドは `manage.py` にあります。

## 構成

- `compose.yaml` — db / adminer / entry / mcp の定義
- `compose.lock.yaml` — 上流イメージのダイジェスト固定（`manage.py lock` が更新）
- `sql/` — スキーマ、登録用関数、ロールと権限
- `entry/` — 登録画面（Python / FastAPI）
- `mcp/` — MCP サーバ（Python）
- `manage.py` — 初期化・起動・ダンプ・復元・バックアップ

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

CI（`.github/workflows/ci.yml`）でも同じ lint・コンパイル・テストと、entry / mcp の
Docker イメージのビルドを行います。
