# Salesforce JWT Authentication Tester

A command-line tool to verify Salesforce JWT authentication configuration. Use this to test your JWT setup before implementing it in your applications.

## Prerequisites

The following tools must be installed on your system:

```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install openjdk-11-jdk openssl jq curl

# RHEL/CentOS/Fedora
sudo dnf install java-11-openjdk openssl jq curl

# macOS with Homebrew
brew install openjdk openssl jq
```

Verify the installations:
```bash
java -version    # Should show Java 11 or higher
openssl version
jq --version
curl --version
```

## Setup

1. Clone this repository:
   ```bash
   git clone https://github.com/sfa1z/sf-jwt-tester.git
   cd sf-jwt-tester
   ```

2. Make the script executable:
   ```bash
   chmod +x sf-jwt-test
   ```

3. Create your environment files from the examples:
   ```bash
   cp .env.uat.example .env.uat
   cp .env.prod.example .env.prod
   ```

## Configuration

### 1. Create a Connected App in Salesforce

1. Navigate to Setup → App Manager → New Connected App

2. Fill in the basic information:
   - Connected App Name
   - API Name
   - Contact Email

3. Configure OAuth Settings:
   - Enable OAuth Settings: ✓
   - Callback URL: `http://localhost:8080/callback` 
     - Since we're using JWT flow, not web server OAuth flow, this is just a placeholder
   - Use digital signatures: ✓
   - Upload your certificate

4. Configure Additional Settings:
   - IP Relaxation: Set to 'Relaxed' for the Connected App
   - Require Secret for Web Server Flow: Not needed for JWT flow

5. After Creation:
   - Save the Consumer Key (Client ID) - this is what you'll need for configuration
   - Consumer Secret is not required for JWT authentication
   - Share the following with your integration team:
     - Consumer Key
     - JWT Certificate
     - Certificate Key

### 2. Create a Certificate and Keystore

1. Generate a keystore and certificate:
   ```bash
   keytool -genkeypair -alias salesforce -keyalg RSA -keystore your-org-id.jks \
           -storepass your-password -validity 365
   ```

2. Export the certificate:
   ```bash
   keytool -exportcert -alias salesforce -keystore your-org-id.jks \
           -file certificate.crt -storepass your-password
   ```

3. Upload `certificate.crt` to your Salesforce Connected App

### 3. Configure Environment Files

Edit `.env.uat` and `.env.prod` with your settings:

```bash
# Find these values in your Salesforce Connected App settings
CLIENT_ID="your_connected_app_client_id"
USERNAME="your_salesforce_username"
KEYSTORE_PATH="your-org-id.jks"
KEYSTORE_PASSWORD="your-keystore-password"
```

## Usage

Test UAT/Sandbox authentication:
```bash
./sf-jwt-test uat
```

Test Production authentication:
```bash
./sf-jwt-test prod
```

## Common Issues and Solutions

### Invalid Client Credentials

**Error:**
```json
{"error":"invalid_client","error_description":"invalid client credentials"}
```

**Solutions:**
1. Verify CLIENT_ID matches your Connected App's Consumer Key
2. Ensure the certificate in the keystore matches the one in your Connected App
3. Check if the Connected App is installed in your org

### Certificate Issues

**Error:**
```
keytool error: java.io.IOException: Keystore was tampered with, or password was incorrect
```

**Solutions:**
1. Verify your KEYSTORE_PASSWORD
2. Ensure the keystore file exists at KEYSTORE_PATH
3. Try recreating the keystore

### Permission Issues

If you get access denied errors:
1. Ensure the Connected App is installed in your org
2. Check that your user has the required permission sets
3. Verify the OAuth scopes in your Connected App settings
