#!/bin/bash

# Show usage if no environment specified
if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <environment>"
    echo "Environment can be: uat, uat2 or prod"
    echo "Example: $0 uat"
    exit 1
fi

# Get environment from command line
ENV=$(echo "$1" | tr '[:upper:]' '[:lower:]')  # Convert to lowercase

# Validate environment
if [[ "$ENV" != "uat" && "$ENV" != "prod"  && "$ENV" != "uat2" ]]; then
    echo "Error: Environment must be either 'uat', 'uat2' or 'prod'"
    exit 1
fi

# Load environment file
ENV_FILE=".env.${ENV}"
if [ ! -f "$ENV_FILE" ]; then
    echo "Error: Environment file $ENV_FILE not found"
    exit 1
fi

# Source the environment file
set -a  # automatically export all variables
source "$ENV_FILE"
set +a

# Validate required variables
REQUIRED_VARS=("CLIENT_ID" "USERNAME" "KEYSTORE_PATH" "KEYSTORE_PASSWORD" "LOGIN_URL" "JWT_AUDIENCE")
for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var}" ]; then
        echo "Error: $var is not set in $ENV_FILE"
        exit 1
    fi
done

# The auth endpoint (remove any trailing slash from LOGIN_URL)
LOGIN_URL="${LOGIN_URL%/}"  # Remove trailing slash if present
AUTH_ENDPOINT="${LOGIN_URL}/services/oauth2/token"
# JWT_AUDIENCE="${LOGIN_URL}/services/oauth2/token"

# Check if required tools are installed
for tool in openssl jq keytool; do
    if ! command -v $tool >/dev/null 2>&1; then
        echo "Error: $tool is required but not installed"
        exit 1
    fi
done

# Print configuration (mask sensitive data)
echo "Environment: $ENV"
echo "Login URL: $LOGIN_URL"
echo "JWT Audience: $JWT_AUDIENCE"
echo "Client ID: ${CLIENT_ID:0:5}...${CLIENT_ID: -5}"
echo "Username: $USERNAME"
echo "Keystore Path: $KEYSTORE_PATH"

# Create a temporary directory for key extraction
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

# Extract private key from keystore
echo -e "\nExtracting private key from keystore..."
keytool -importkeystore \
    -srckeystore "$KEYSTORE_PATH" \
    -srcstorepass "$KEYSTORE_PASSWORD" \
    -destkeystore "$TEMP_DIR/temp.p12" \
    -deststoretype PKCS12 \
    -deststorepass "temp123" 2>/dev/null

openssl pkcs12 -in "$TEMP_DIR/temp.p12" -nodes \
    -passin pass:temp123 \
    -nocerts -out "$TEMP_DIR/private.pem" 2>/dev/null

# Function to create JWT header and payload
create_jwt_parts() {
    # Create header and payload as single-line JSON
    header=$(echo -n '{"alg":"RS256","typ":"JWT"}')

    # Get current timestamp and expiration (5 minutes from now)
    now=$(date +%s)
    exp=$((now + 300))

    # Create payload as single-line JSON
    payload=$(echo -n "{\"iss\":\"$CLIENT_ID\",\"sub\":\"$USERNAME\",\"aud\":\"$JWT_AUDIENCE\",\"exp\":$exp,\"iat\":$now}")

    # ,\"grant_type\":'urn:ietf:params:oauth:grant-type:jwt-bearer'}")

    # Base64url encode header and payload - ensure single line output
    b64_header=$(echo -n "$header" | base64 -w0 | tr '/+' '_-' | tr -d '=')
    b64_payload=$(echo -n "$payload" | base64 -w0 | tr '/+' '_-' | tr -d '=')

    echo -n "${b64_header}.${b64_payload}"
}

# Create JWT parts
jwt_parts=$(create_jwt_parts)

# Sign the JWT using the extracted private key
signature=$(echo -n "$jwt_parts" | openssl dgst -sha256 -sign "$TEMP_DIR/private.pem" | base64 -w0 | tr '/+' '_-' | tr -d '=')

# Combine to create final JWT
jwt="${jwt_parts}.${signature}"

# Debug output
echo -e "\nDebug Info:"
echo "Header (decoded): $header"
echo "Payload (decoded): $payload"
echo "JWT parts: $jwt_parts"
echo -e "Final JWT (single line):\n$jwt"

# Make the OAuth request with verbose curl output
echo -e "\nSending authentication request to Salesforce..."
echo "Using endpoint: $AUTH_ENDPOINT"

# Separate curl verbose output to stderr and response to stdout
response=$(curl -v "${AUTH_ENDPOINT}" \
    -d "grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer" \
    -d "assertion=${jwt}" \
    -H "Content-Type: application/x-www-form-urlencoded" 2>curl_stderr.log)

# Print verbose output
echo -e "\nCurl Debug Output:"
cat curl_stderr.log
rm curl_stderr.log

# Print raw response
echo -e "\nRaw Response from Salesforce:"
echo "$response"

# Try to pretty print if it's valid JSON
echo -e "\nFormatted Response:"
if echo "$response" | jq -e '.' >/dev/null 2>&1; then
    echo "$response" | jq '.'

    # Check for error first
    if echo "$response" | jq -e '.error' >/dev/null 2>&1; then
        echo -e "\nError! Authentication failed:"
        echo "Error: $(echo "$response" | jq -r '.error')"
        echo "Description: $(echo "$response" | jq -r '.error_description')"
        exit 1
    fi

    # If no error, extract and display important parts
    access_token=$(echo "$response" | jq -r '.access_token')
    instance_url=$(echo "$response" | jq -r '.instance_url')

    echo -e "\nSuccess! Access token received."
    echo "Instance URL: $instance_url"
    echo "Access Token: ${access_token:0:20}..." # Show only first 20 chars
else
    echo "Response is not valid JSON"
    echo "Error! Invalid response from server."
    exit 1
fi
