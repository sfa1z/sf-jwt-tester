#!/bin/bash

# Check for OpenSSL and keytool
if ! command -v openssl &> /dev/null || ! command -v keytool &> /dev/null; then
    echo "Error: Both OpenSSL and Java keytool (JDK) are required"
    exit 1
fi

# Get password
read -s -p "Enter keystore password: " PASSWORD
echo
read -s -p "Confirm password: " PASSWORD_CONFIRM
echo

if [ "$PASSWORD" != "$PASSWORD_CONFIRM" ]; then
    echo "Error: Passwords do not match"
    exit 1
fi

if [ ${#PASSWORD} -lt 8 ]; then
    echo "Error: Password must be at least 8 characters long"
    exit 1
fi

# Create working directory
OUTPUT_DIR="salesforce_jwt_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$OUTPUT_DIR"
cd "$OUTPUT_DIR"

echo -e "\nGenerating certificate and keystore..."

# Generate private key and certificate directly
openssl req -x509 -newkey rsa:2048 -sha256 -days 365 \
    -nodes \
    -keyout server.key \
    -out server.crt \
    -subj "/C=US/ST=State/L=City/O=Organization/OU=Unit/CN=example.com"

# Convert to PKCS12
openssl pkcs12 -export \
    -in server.crt \
    -inkey server.key \
    -out temp.p12 \
    -name salesforce-jwt \
    -password pass:$PASSWORD

# Convert to JKS
keytool -importkeystore \
    -srckeystore temp.p12 \
    -srcstoretype PKCS12 \
    -srcstorepass $PASSWORD \
    -destkeystore server.jks \
    -deststoretype JKS \
    -deststorepass $PASSWORD

# Clean up intermediate PKCS12
rm temp.p12

# Set permissions
chmod 600 server.key server.jks
chmod 644 server.crt

echo -e "\nGenerated files in $OUTPUT_DIR:"
echo "- server.crt  : Upload this to Salesforce Connected App"
echo "- server.key  : Private key (keep secure)"
echo "- server.jks  : Java KeyStore for testing"
echo -e "\nKeystore details:"
echo "- Keystore file: server.jks"
echo "- Keystore password: (the one you entered)"
echo "- Key alias: salesforce-jwt"
