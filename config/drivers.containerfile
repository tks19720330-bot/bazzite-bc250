# =========================================================
# 第1ステージ: 本番イメージからカーネルバージョンを動的に抽出
# =========================================================
FROM $BASE_IMAGE AS bazzite-base

# =========================================================
# 第2ステージ: ドライバのビルドと、成果物の存在確認（ログ出力）
# =========================================================
# ※fedora:44ではなく、Bazzite自身をビルドベースにすることでリポジトリ設定を完全に一致させます
FROM $BASE_IMAGE AS builder

# 一時領域にカーネルバージョンファイルをコピー
COPY --from=bazzite-base /usr/share/ublue-os/kernel-version /tmp/kernel-version

# ビルドツールの導入と、正確な kernel-devel の導入、およびシンボリックリンクの強制構築
RUN ublue_kernel=$(cat /tmp/kernel-version) && \
    echo "Target Kernel: ${ublue_kernel}" && \
    #
    # 必要なパッケージを一斉に導入
    dnf install -y git make gcc gcc-c++ elfutils-libelf-devel kernel-devel-${ublue_kernel} && \
    #
    # 【超重要】/lib/modules/.../build のシンボリックリンクを確実に手動で作成する
    mkdir -p /lib/modules/${ublue_kernel} && \
    ln -s /usr/src/kernels/${ublue_kernel} /lib/modules/${ublue_kernel}/build && \
    #
    # -----------------------------------------------------
    # 1. WI-FI DRIVER BUILD START (aic8800)
    # -----------------------------------------------------
    echo "=========================================" && \
    echo "1. WI-FI DRIVER BUILD START (aic8800)" && \
    echo "=========================================" && \
    git clone https://github.com/shenmintao/aic8800d80.git /usr/src/aic8800 && \
    cd /usr/src/aic8800 && \
    # aic8800d80のMakefileの構造に合わせ、明示的にビルドパスを指定
    make -C /lib/modules/${ublue_kernel}/build M=$PWD modules && \
    #
    echo "--> [FACT CHECK] WI-FI DRIVER FILE LIST:" && \
    ls -la /usr/src/aic8800/*.ko || echo "Wi-Fi Driver Build Failed" && \
    #
    # -----------------------------------------------------
    # 2. SENSOR DRIVER BUILD START (nct6687)
    # -----------------------------------------------------
    echo "=========================================" && \
    echo "2. SENSOR DRIVER BUILD START (nct6687)" && \
    echo "=========================================" && \
    git clone https://github.com/Fred78290/nct6687d.git /usr/src/nct6687 && \
    cd /usr/src/nct6687 && \
    make -C /lib/modules/${ublue_kernel}/build M=$PWD modules && \
    #
    echo "--> [FACT CHECK] SENSOR DRIVER FILE LIST:" && \
    ls -la /usr/src/nct6687/*.ko || echo "Sensor Driver Build Failed" && \
    echo "========================================="

# =========================================================
# 第3ステージ: ログ確認のため、ビルド完了の最小構成で受ける
# =========================================================
FROM $BASE_IMAGE
# 一旦空の状態で受け、GitHub Actionsが正常終了するかログを確認します
