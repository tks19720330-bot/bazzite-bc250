# =========================================================
# 第1ステージ: 本番イメージからカーネルバージョンを動的に抽出
# =========================================================
FROM $BASE_IMAGE AS bazzite-base

# =========================================================
# 第2ステージ: ドライバのビルドと、成果物の存在確認（ログ出力）
# =========================================================
FROM fedora:44 AS builder

# 本番イメージからカーネルバージョンのテキストファイルを一時領域にコピー
COPY --from=bazzite-base /usr/share/ublue-os/kernel-version /tmp/kernel-version

# 共通ビルドツールのインストール
RUN dnf copr enable -y ublue-os/packages \
    && dnf install -y git make gcc kernel-headers \
    && dnf clean all

# 【最重要】ビルドを実行し、その直後にファイルの存在確認をログに出力する
RUN ublue_kernel=$(cat /tmp/kernel-version) \
    && dnf install -y kernel-devel-${ublue_kernel} \
    \
    && echo "=========================================" \
    && echo "1. WI-FI DRIVER BUILD START (aic8800)" \
    && echo "=========================================" \
    && git clone https://github.com/shenmintao/aic8800d80.git /usr/src/aic8800 \
    && cd /usr/src/aic8800 \
    && make -C /lib/modules/${ublue_kernel}/build M=$PWD modules \
    \
    && echo "--> [FACT CHECK] WI-FI DRIVER FILE LIST:" \
    && ls -la /usr/src/aic8800/*.ko \
    \
    && echo "=========================================" \
    && echo "2. SENSOR DRIVER BUILD START (nct6687)" \
    && echo "=========================================" \
    && git clone https://github.com/Fred78290/nct6687d.git /usr/src/nct6687 \
    && cd /usr/src/nct6687 \
    && make -C /lib/modules/${ublue_kernel}/build M=$PWD modules \
    \
    && echo "--> [FACT CHECK] SENSOR DRIVER FILE LIST:" \
    && ls -la /usr/src/nct6687/*.ko \
    && echo "========================================="

# =========================================================
# 第3ステージ: ログ確認のため、ビルド完了の最小構成で受ける
# =========================================================
FROM $BASE_IMAGE
# (一旦ファイル移動のロジックはすべて外し、ビルドログの確認に集中します)
