# =========================================================
# 第1ステージ: 開発ツールを展開し、指定ドライバをコンパイルする環境
# =========================================================
FROM ghcr.io/ublue-os/main-kernel:latest AS kernel-source
FROM fedora:40 AS builder

# 1. コンパイルに必須となるパッケージのインストール
RUN dnf install -y \
    git \
    make \
    gcc \
    kernel-devel \
    kernel-headers \
    && dnf clean all

# 2. Wi-Fiドライバ (shenmintao/aic8800d80) のビルド
RUN git clone https://github.com/shenmintao/aic8800d80.git /usr/src/aic8800 \
    && cd /usr/src/aic8800 \
    && make -C /lib/modules/$(rpm -q --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}\n' kernel-devel)/build M=$PWD modules

# 3. センサー用ドライバ (Fred78290/nct6687d) のビルド
RUN git clone https://github.com/Fred78290/nct6687d.git /usr/src/nct6687 \
    && cd /usr/src/nct6687 \
    && make -C /lib/modules/$(rpm -q --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}\n' kernel-devel)/build M=$PWD modules

# =========================================================
# 第2ステージ: 成果物（.koとファームウェア）を本番イメージへ完全結合
# =========================================================
FROM $BASE_IMAGE

# コンパイル済みのカーネルオブジェクト（.ko）を本番領域にコピー
COPY --from=builder /usr/src/aic8800/*.ko /usr/lib/modules/extramodules/
COPY --from=builder /usr/src/nct6687/*.ko /usr/lib/modules/extramodules/

# aic8800d80の正確な格納場所(images/)からファームウェアバイナリを本番環境へ配置
COPY --from=builder /usr/src/aic8800/images/*.bin /usr/lib/firmware/

# OSに新しいドライバの依存関係を認識させ、起動時に自動ロードする設定を追加
RUN depmod -a $(lookaside-kernel-version) \
    && echo "aic8800" > /etc/modules-load.d/aic8800.conf \
    && echo "nct6687" > /etc/modules-load.d/nct6687.conf
