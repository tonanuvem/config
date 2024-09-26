HOST=$(echo "$AWS_CONTAINER_CREDENTIALS_FULL_URI" | sed 's|/latest.*||')
TOKEN=$(curl -s -X PUT "$HOST"/latest/api/token -H "X-aws-ec2-metadata-token-ttl-seconds: 60")
OUTPUT=$(curl -s "$HOST/latest/meta-data/container/security-credentials" -H "X-aws-ec2-metadata-token: $TOKEN")
echo "[default]" > ~/credentials
echo "AWS_ACCESS_KEY_ID=$(echo "$OUTPUT" | jq -r '.AccessKeyId')" >> ~/credentials
echo "AWS_SECRET_ACCESS_KEY=$(echo "$OUTPUT" | jq -r '.SecretAccessKey')" >> ~/credentials
echo "AWS_SESSION_TOKEN=$(echo "$OUTPUT" | jq -r '.Token')" >> ~/credentials
echo "region=us-east-1" >> ~/credentials
