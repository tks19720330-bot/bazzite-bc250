# =========================================================
# 第1ステージ: 本番イメージからカーネルバージョンを動的に抽出
# =========================================================
FROM $BASE_IMAGE AS bazzite-base

# =========================================================
# 第2ステージ: 抽出したバージョンを使ってドライバをクリーンビルド
# =========================================================
FROM fedora:44 AS builder

# 1. 本番イメージからカーネルバージョンのテキストファイルを一時領域にコピー
COPY --from=bazzite-base /usr/share/ublue-os/kernel-version /tmp/kernel-version

# 2. Bazzite専用リポジトリの有効化と、共通ビルドツールのインストール
RUN dnf copr enable -y ublue-os/packages \
    && dnf install -y git make gcc kernel-headers \
    && dnf clean all

# 3. 1つのRUN命令内で、カーネルバージョンの取得からビルドまでを一気通貫で実行
RUN ublue_kernel=$(cat /tmp/kernel-version) \
    && dnf install -y kernel-devel-${ublue_kernel} \
    && git clone https://github.com/shenmintao/aic8800d80.git /usr/src/aic8800 \
    && cd /usr/src/aic8800 \
    && make -C /lib/modules/${ublue_kernel}/build M=$PWD modules \
    && git clone https://github.com/Fred78290/nct6687d.git /usr/src/nct6687 \
    && cd /usr/src/nct6687 \
    && make -C /lib/modules/${ublue_kernel}/build M=$PWD modules

# 4. 【修正ポイント】ワイルドカードを使わず、明確に分けた固定フォルダ内へ確実に集約
RUN mkdir -p /tmp/out/modules/ /tmp/out/firmware/ \
    && cp /usr/src/aic8800/*.ko /tmp/out/modules/ \
    && cp /usr/src/nct6687/*.ko /tmp/out/modules/ \
    && cp /usr/src/aic8800/images/*.bin /tmp/out/firmware/

# =========================================================
# 第3ステージ: 成果物を本番イメージへ100%安全に仕分け配置
# =========================================================
FROM $BASE_IMAGE

# 【修正ポイント】末尾の「/*」を完全に排除。
# フォルダそのものを丸ごとコピーさせることで、コンテナエンジンのパース失敗を物理的に防ぎます
COPY --from=builder /tmp/kernel-version /tmp/kernel-version
COPY --from=builder /tmp/out/modules/ /tmp/stage_modules/
COPY --from=builder /tmp/out/firmware/ /tmp/stage_firmware/

# 最終処理: シェル環境（RUN）の内部だけで lookaside-kernel-version を展開
# サイレント失敗の原因となる「rm -rf」はあえて排除し、何かあればActionsが赤文字で落ちるようにします
RUN ublue_kernel=$(lookaside-kernel-version) \
    && mkdir -p /usr/lib/modules/${ublue_kernel}/extra/ \
    && cp /tmp/stage_modules/*.ko /usr/lib/modules/${ublue_kernel}/extra/ \
    && mkdir -p /usr/lib/firmware/aic8800/ \
    && cp /tmp/stage_firmware/*.bin /usr/lib/firmware/ \
    && cp /tmp/stage_firmware/*.bin /usr/lib/firmware/aic8800/ \
    && depmod -a ${ublue_kernel} \
    && echo "aic8800" > /etc/modules-load.d/aic8800.conf \
    && echo "nct6687" > /etc/modules-load.d/nct6687.conf
