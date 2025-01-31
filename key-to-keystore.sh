#!/bin/bash

# Check for required tools
if ! command -v openssl &> /dev/null || ! command -v keytool &> /dev/null; then
    echo "Error: Both OpenSSL and Java keytool (JDK) are required"
    exit 1
fi

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <server.key>"
    exit 1
fi

KEY_FILE=$1

if [ ! -f "$KEY_FILE" ]; then
    echo "Error: Key file $KEY_FILE not found"
    exit 1
fi

# Get password
read -s -p "Enter keystore password: " PASSWORD
echo

# Generate certificate from key
openssl req -new -x509 -key "$KEY_FILE" -out temp.crt -days 365 \
    -subj "/C=US/ST=State/L=City/O=Organization/OU=Unit/CN=example.com"

# Convert to PKCS12
openssl pkcs12 -export \
    -in temp.crt \
    -inkey "$KEY_FILE" \
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

# Clean up temporary files
rm temp.crt temp.p12

echo -e "\nCreated server.jks with your key"
echo "Keystore password: (the one you entered)"
echo "Key alias: salesforce-jwt"
