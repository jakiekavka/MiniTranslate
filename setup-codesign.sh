#!/bin/bash
# 一次性设置：创建持久代码签名证书，只需运行一次
# 使用自签名证书后，每次重编译不会丢失权限

CERT_NAME="Mini Translate Developer"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

# 检查证书是否已可用
if security find-identity -p codesigning 2>/dev/null | grep -q "$CERT_NAME"; then
    echo "证书 '$CERT_NAME' 已存在，无需重复创建。"
    exit 0
fi

echo "=== 创建代码签名证书 '$CERT_NAME' ==="

# 创建 openssl 配置文件，指定代码签名扩展
cat > /tmp/mt-openssl.cnf << 'OPENSSL_CONF'
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_ext
prompt = no

[req_distinguished_name]
CN = Mini Translate Developer
O = Mini Translate
C = CN

[v3_ext]
basicConstraints = critical,CA:FALSE
keyUsage = critical,digitalSignature
extendedKeyUsage = codeSigning
OPENSSL_CONF

# 生成自签名证书（带代码签名扩展）
openssl req -new -x509 -days 3650 -nodes \
    -config /tmp/mt-openssl.cnf \
    -newkey rsa:2048 \
    -keyout /tmp/mt-key.pem \
    -out /tmp/mt-cert.pem 2>/dev/null

if [ ! -f /tmp/mt-cert.pem ]; then
    echo "错误: 证书生成失败"
    exit 1
fi

# 转换为 p12（legacy 模式兼容 macOS keychain 导入）
openssl pkcs12 -export \
    -in /tmp/mt-cert.pem \
    -inkey /tmp/mt-key.pem \
    -out /tmp/mt-cert.p12 \
    -passout pass:minitranslate \
    -name "$CERT_NAME" \
    -legacy 2>/dev/null

# 导入到钥匙串 (-A: 允许所有应用免弹窗访问私钥)
security import /tmp/mt-cert.p12 \
    -k "$KEYCHAIN" \
    -P minitranslate \
    -A 2>/dev/null

# 清理临时文件
rm -f /tmp/mt-key.pem /tmp/mt-cert.pem /tmp/mt-cert.p12 /tmp/mt-openssl.cnf

# 验证
echo ""
if security find-identity -p codesigning 2>/dev/null | grep -q "$CERT_NAME"; then
    echo "证书创建成功。运行 bash build.sh 重新构建。"
else
    echo "证书创建失败，请检查钥匙串权限。"
    exit 1
fi
