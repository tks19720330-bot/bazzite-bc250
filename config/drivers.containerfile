# =========================================================
# 第1ステージ: 本番イメージからカーネルバージョンを動的に抽出してビルド
# =========================================================
# 最初に本番用Bazziteイメージ（$BASE_IMAGE）をベースにして、中身のバージョン情報を正確に取得する
FROM $BASE_IMAGE AS bazzite-base
FROM fedora:44 AS builder

# 本番イメージから、正確なカーネルバージョン（例: 6.19.14-ogc5.1...）の文字列を動的にコピーして環境変数に注入
COPY --from=bazzite-base /usr/share/ublue-os/kernel-version /tmp/kernel-version
RUN export TARGET_KERNEL=$(cat /tmp/kernel-version) && echo "Building for kernel: ${TARGET_KERNEL}"

# 1. Bazzite専用のカーネル開発用リポジトリ（Copr）を有効化し、実機と100%完全一致する開発パッケージを自動検索してインストール
RUN dnf copr enable -y ublue-os/packages \
    && TARGET_KERNEL=$(cat /tmp/kernel-version) \
    && dnf install -y \
    git \
    make \
    gcc \
    kernel-devel-${TARGET_KERNEL} \
    kernel-headers \
    && dnf clean all

# 2. Wi-Fiドライバ (shenmintao/aic8800d80) の自動追従ビルド
RUN git clone https://github.com/shenmintao/aic8800d80.git /usr/src/aic8800 \
    && cd /usr/src/aic8800 \
    && TARGET_KERNEL=$(cat /tmp/kernel-version) \
    && make -C /lib/modules/${TARGET_KERNEL}/build M=$PWD modules

# 3. センサー用ドライバ (Fred78290/nct6687d) の自動追従ビルド
RUN git clone https://github.com/Fred78290/nct6687d.git /usr/src/nct6687 \
    && cd /usr/src/nct6687 \
    && TARGET_KERNEL=$(cat /tmp/kernel-version) \
    && make -C /lib/modules/${TARGET_KERNEL}/build M=$PWD modules

# =========================================================
# 第2ステージ: 成果物を本番イメージへ完全結合
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
