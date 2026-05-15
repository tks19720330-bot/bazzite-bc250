# =========================================================
# 第1ステージ: 本番イメージからカーネルバージョンを動的に抽出
# =========================================================
FROM $BASE_IMAGE AS bazzite-base

# =========================================================
# 第2ステージ: 抽出したバージョンを環境変数に固定してコンパイル
# =========================================================
FROM fedora:44 AS builder

# 本番イメージからカーネルバージョンのテキストファイルを一時領域にコピー
COPY --from=bazzite-base /usr/share/ublue-os/kernel-version /tmp/kernel-version

# 【ここが重要】ファイルの中身を読み込み、このステージ全体の環境変数（ENV）として完全に固定する
# これにより、これ以降のすべてのRUNコマンドで ${TARGET_KERNEL} が安全に使用可能になります
RUN echo "TARGET_KERNEL=$(cat /tmp/kernel-version)" >> /etc/environment
ENV ENV_FILE="/etc/environment"

# 1. Bazzite専用リポジトリの有効化と、正確な kernel-devel のインストール
RUN desm() { . /etc/environment; echo $TARGET_KERNEL; } \
    && dnf copr enable -y ublue-os/packages \
    && TARGET_KERNEL=$(desm) \
    && dnf install -y \
    git \
    make \
    gcc \
    kernel-devel-${TARGET_KERNEL} \
    kernel-headers \
    && dnf clean all

# 2. Wi-Fiドライバ (shenmintao/aic8800d80) のビルド
RUN . /etc/environment \
    && git clone https://github.com/shenmintao/aic8800d80.git /usr/src/aic8800 \
    && cd /usr/src/aic8800 \
    && make -C /lib/modules/${TARGET_KERNEL}/build M=$PWD modules

# 3. センサー用ドライバ (Fred78290/nct6687d) のビルド
RUN . /etc/environment \
    && git clone https://github.com/Fred78290/nct6687d.git /usr/src/nct6687 \
    && cd /usr/src/nct6687 \
    && make -C /lib/modules/${TARGET_KERNEL}/build M=$PWD modules

# =========================================================
# 第3ステージ: 成果物を本番イメージへ完全結合
# =========================================================
FROM $BASE_IMAGE

# コンパイル済みのカーネルオブジェクト（.ko）を本番領域にコピー
COPY --from=builder /usr/src/aic8800/*.ko /usr/lib/modules/extramodules/
COPY --from=builder /usr/src/nct6687/*.ko /usr/lib/modules/extramodules/

# aic8800d80に必要なファームウェアバイナリを配置
COPY --from=builder /usr/src/aic8800/images/*.bin /usr/lib/firmware/

# 動的に取得したカーネルバージョン名に基づき、依存関係を更新して自動ロードを設定
RUN TARGET_KERNEL=$(lookaside-kernel-version) \
    && depmod -a ${TARGET_KERNEL} \
    && echo "aic8800" > /etc/modules-load.d/aic8800.conf \
    && echo "nct6687" > /etc/modules-load.d/nct6687.conf
