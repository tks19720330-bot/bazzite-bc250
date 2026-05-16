# =========================================================
# 第1ステージ: 本番イメージからカーネルバージョンを動的に抽出
# =========================================================
FROM $BASE_IMAGE AS bazzite-base

# =========================================================
# 第2ステージ: 抽出したバージョンを「ENV」に完全固定してビルド
# =========================================================
FROM fedora:44 AS builder

# 本番Bazziteから正確なカーネルバージョンのテキストをコピー
COPY --from=bazzite-base /usr/share/ublue-os/kernel-version /tmp/kernel-version

# 【本質的修正】catした中身をコンテナ自体の環境変数（ENV）として永続化
# これにより、これ以降のすべてのRUN命令で、途切れることなく一貫して ${TARGET_KERNEL} が使えます
AUTO_KERNEL_VERSION=$(cat /tmp/kernel-version)
ENV TARGET_KERNEL=$AUTO_KERNEL_VERSION

# 1. 正確な kernel-devel のインストール
RUN dnf copr enable -y ublue-os/packages \
    && dnf install -y git make gcc kernel-devel-${TARGET_KERNEL} kernel-headers \
    && dnf clean all

# 2. Wi-Fiドライバのビルド（確実に正しいkernel-develのパスを参照）
RUN git clone https://github.com/shenmintao/aic8800d80.git /usr/src/aic8800 \
    && cd /usr/src/aic8800 \
    && make -C /lib/modules/${TARGET_KERNEL}/build M=$PWD modules

# 3. センサー用ドライバのビルド
RUN git clone https://github.com/Fred78290/nct6687d.git /usr/src/nct6687 \
    && cd /usr/src/nct6687 \
    && make -C /lib/modules/${TARGET_KERNEL}/build M=$PWD modules

# =========================================================
# 第3ステージ: 成果物を本番イメージへ100%安全に結合
# =========================================================
FROM $BASE_IMAGE

# 第2ステージで確定した環境変数を、第3ステージ（本番環境）側にも再度バトンリレー
COPY --from=builder /tmp/kernel-version /tmp/kernel-version
AUTO_KERNEL_VERSION=$(cat /tmp/kernel-version)
ENV TARGET_KERNEL=$AUTO_KERNEL_VERSION

# 不確定なスクリプトに頼らず、ENV（環境変数）に固定された絶対パスへダイレクト配置
RUN mkdir -p /usr/lib/modules/${TARGET_KERNEL}/extra/

# 成果物の確実なコピーと配置
COPY --from=builder /usr/src/aic8800/*.ko /usr/lib/modules/${TARGET_KERNEL}/extra/
COPY --from=builder /usr/src/nct6687/*.ko /usr/lib/modules/${TARGET_KERNEL}/extra/

# ファームウェアの配置（サブディレクトリ側にも重複配置して認識漏れを完全防御）
mkdir -p /usr/lib/firmware/aic8800/
COPY --from=builder /usr/src/aic8800/images/*.bin /usr/lib/firmware/
COPY --from=builder /usr/src/aic8800/images/*.bin /usr/lib/firmware/aic8800/

# カーネルの依存関係を更新し、自動ロードを設定
RUN depmod -a ${TARGET_KERNEL} \
    && echo "aic8800" > /etc/modules-load.d/aic8800.conf \
    && echo "nct6687" > /etc/modules-load.d/nct6687.conf \
    && rm -f /tmp/kernel-version
