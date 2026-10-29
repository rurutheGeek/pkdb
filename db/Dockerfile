# ポケモンDBの PostgreSQL に pgvector を足したイメージ。
#
# 公式の pgvector/pgvector は Debian だけで、入れ替えると libc が musl から
# glibc に変わり、テキストの照合順序（en_US.utf8）がずれる。既存の btree を
# 全部 REINDEX することになるので、同じ Alpine・同じ 15.15 の上に拡張だけを
# 組む。基底イメージは compose.yaml の build.args でダイジェスト固定する。
ARG BASE=postgres:15.15-alpine
FROM ${BASE}

ARG PGVECTOR_VERSION=v0.8.7

# Alpine の clang は clang-19 という名前で入らず、PostgreSQL の PGXS が
# ビットコード（.bc）を作るために clang-19 を直接呼ぶ。JIT のインライン化は
# 使わないので、ビットコードの生成だけ止める（with_llvm=no）。
# apps-01 はメモリが少ない（約3GiB）ので、並列は2に抑える（それでも数十秒）。
RUN apk add --no-cache --virtual .build-deps build-base git \
 && git clone --depth 1 --branch "${PGVECTOR_VERSION}" https://github.com/pgvector/pgvector.git /tmp/pgvector \
 && make -C /tmp/pgvector -j2 with_llvm=no \
 && make -C /tmp/pgvector install with_llvm=no \
 && rm -rf /tmp/pgvector \
 && apk del .build-deps
