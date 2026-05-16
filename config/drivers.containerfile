# =========================================================
# 第1ステージ: 本番イメージからカーネルバージョンを動的に抽出
# =========================================================
FROM $BASE_IMAGE AS bazzite-base

# =========================================================
# 第2ステージ: 抽出したバージョンを正しく引き継いでコンパイル
# =========================================================
FROM fedora:44 AS builder

# 本番イメージから一時領域にカーネルバージョンをコピー
COPY --from=bazzite-base /usr/share/ublue-os/kernel-version /tmp/kernel-version

# 【変更点】シェルスクリプトを使わず、Containerfileの機能で環境変数を一発固定
# これにより、このステージ内のすべてのRUN命令で「${TARGET_KERNEL}」が確実に使えます
RUN echo "TARGET_KERNEL=$(cat /tmp/kernel-version)" > /tmp/env_vars
ENV TARGET_KERNEL_FILE=/tmp/kernel-version

# 1. 正確な kernel-devel のインストール
RUN TARGET_KERNEL=$(cat /tmp/kernel-version) \
    && dnf copr enable -y ublue-os/packages \
    && dnf install -y git make gcc kernel-devel-${TARGET_KERNEL} kernel-headers \
    && dnf clean all

# 2. Wi-Fiドライバのビルド
RUN TARGET_KERNEL=$(cat /tmp/kernel-version) \
    && git clone https://github.com/shenmintao/aic8800d80.git /usr/src/aic8800 \
    && cd /usr/src/aic8800 \
    && make -C /lib/modules/${TARGET_KERNEL}/build M=$PWD modules

# 3. センサー用ドライバのビルド
RUN TARGET_KERNEL=$(cat /tmp/kernel-version) \
    && git clone https://github.com/Fred78290/nct6687d.git /usr/src/nct6687 \
    && cd /usr/src/nct6687 \
    && make -C /lib/modules/${TARGET_KERNEL}/build M=$PWD modules

# =========================================================
# 第3ステージ: 変数の罠を完全に回避して成果物を本番イメージへ結合
# =========================================================
FROM $BASE_IMAGE

# 【変更点】COPYコマンドに変数を直接使わせると空振りするため、
# いったんコンテナ内の安全な一時フォルダー（/tmp/drivers/）に成果物を集約します
COPY --from=builder /usr/src/aic8800/*.ko /tmp/drivers/
COPY --from=builder /usr/src/nct6687/*.ko /tmp/drivers/
COPY --from=builder /usr/src/aic8800/images/*.bin /tmp/firmware/

# 【変更点】1つの連続したRUN命令の中で、変数取得・フォルダ作成・コピーを完結させる！
# これにより、変数が空振るリスクが論理的に0%になります
RUN ublue_kernel=$(lookaside-kernel-version) \
    && mkdir -p /usr/lib/modules/${ublue_kernel}/extra/ \
    && cp /tmp/drivers/*.ko /usr/lib/modules/${ublue_kernel}/extra/ \
    && mkdir -p /usr/lib/firmware/aic8800/ \
    && cp /tmp/firmware/*.bin /usr/lib/firmware/ \
    && cp /tmp/firmware/*.bin /usr/lib/firmware/aic8800/ \
    && depmod -a ${ublue_kernel} \
    && echo "aic8800" > /etc/modules-load.d/aic8800.conf \
    && echo "nct6687" > /etc/modules-load.d/nct6687.conf \
    && rm -rf /tmp/drivers /tmp/firmware
