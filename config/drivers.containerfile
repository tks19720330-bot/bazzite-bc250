# =========================================================
# 第1ステージ: 開発ツールを展開し、ドライバをコンパイルする環境
# =========================================================
FROM ghcr.io/ublue-os/main-kernel:latest AS kernel-source
FROM fedora:40 AS builder

# 1. コンパイルに絶対必要な最小限のパッケージをインストール
RUN dnf install -y \
    git \
    make \
    gcc \
    kernel-devel \
    kernel-headers \
    && dnf clean all

# 2. Wi-Fiドライバ (aic8800) のソース取得とビルド
RUN git clone https://github.com/nluka/aic8800_bazzite.git /usr/src/aic8800 \
    && cd /usr/src/aic8800 \
    && make -C /lib/modules/$(rpm -q --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}\n' kernel-devel)/build M=$PWD modules

# 3. センサー用ドライバ (nct6687) のソース取得とビルド
RUN git clone https://github.com/FreddieAkeroyd/nct6687d.git /usr/src/nct6687 \
    && cd /usr/src/nct6687 \
    && make -C /lib/modules/$(rpm -q --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}\n' kernel-devel)/build M=$PWD modules

# =========================================================
# 第2ステージ: 余計なツールを捨て、完成したバイナリだけを本番OSへ結合
# =========================================================
FROM $BASE_IMAGE

# 第1ステージから、コンパイル済みのカーネルオブジェクト（.ko）だけを本番領域にコピー
COPY --from=builder /usr/src/aic8800/*.ko /usr/lib/modules/extramodules/
COPY --from=builder /usr/src/nct6687/*.ko /usr/lib/modules/extramodules/

# OSに新しいドライバの依存関係を認識させ、起動時に自動ロードする設定を追加
RUN depmod -a $(lookaside-kernel-version) \
    && echo "aic8800" > /etc/modules-load.d/aic8800.conf \
    && echo "nct6687" > /etc/modules-load.d/nct6687.conf
