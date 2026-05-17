#!/usr/bin/env bash
set -euxo pipefail

cd /tmp

git clone https://github.com/Fred78290/nct6687d.git
cd nct6687d

make akmod

dnf install -y ./*.rpm

# 生成されたRPMを探してインストール
# find . -name "*.rpm" -exec rpm-ostree install {} \;

# 自動ロード
cat >/etc/modules-load.d/nct6687d.conf <<EOF
nct6687
EOF

# MSI系でsystem fanが見えない場合用
cat >/etc/modprobe.d/nct6687d.conf <<EOF
options nct6687 fan_config=msi_alt1
EOF
