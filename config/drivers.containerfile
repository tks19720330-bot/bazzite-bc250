# =========================================================
# 第1ステージ: 本番イメージからカーネルバージョンを動的に抽出 
# =========================================================
FROM $BASE_IMAGE AS bazzite-base

# =========================================================
# 第2ステージ: ドライバのビルドと、成果物の存在確認（ログ出力）
# =========================================================
FROM $BASE_IMAGE AS builder

# 一時領域にカーネルバージョンファイルをコピー
COPY --from=bazzite-base /usr/share/ublue-os/kernel-version /tmp/kernel-version

# ビルドツールの導入と、正確な kernel-devel の導入、およびシンボリックリンクの構築
RUN ublue_kernel=$(cat /tmp/kernel-version) && \
    echo "Target Kernel: ${ublue_kernel}" && \
    #
    dnf install -y git make gcc gcc-c++ elfutils-libelf-devel kernel-devel-${ublue_kernel} && \
    #
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
    # aic8800のトップのMakefileではなく、ビルドの本体である「bsp」へ環境変数を引き渡して叩く
    make KSRC=/lib/modules/${ublue_kernel}/build ARCH=x86_64 modules && \
    #
    echo "--> [FACT CHECK] WI-FI DRIVER FILE LIST:" && \
    ls -la /usr/src/aic8800/*.ko /usr/src/aic8800/*/*.ko 2>/dev/null || echo "Wi-Fi Driver Build Failed" && \
    #
    # -----------------------------------------------------
    # 2. SENSOR DRIVER BUILD START (nct6687)
    # -----------------------------------------------------
    echo "=========================================" && \
    echo "2. SENSOR DRIVER BUILD START (nct6687)" && \
    echo "=========================================" && \
    git clone https://github.com/Fred78290/nct6687d.git /usr/src/nct6687 && \
    # Makefileが存在する「nct6687d」子ディレクトリに正確に移動してからmakeを叩く
    cd /usr/src/nct6687/nct6687d && \
    make -C /lib/modules/${ublue_kernel}/build M=$PWD modules && \
    #
    echo "--> [FACT CHECK] SENSOR DRIVER FILE LIST:" && \
    ls -la /usr/src/nct6687/nct6687d/*.ko 2>/dev/null || echo "Sensor Driver Build Failed" && \
    echo "========================================="

# =========================================================
# 第3ステージ: ログ確認のため、ビルド完了の最小構成で受ける
# =========================================================
FROM $BASE_IMAGE
