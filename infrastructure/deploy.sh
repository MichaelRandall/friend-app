#!/bin/bash
set -e  # Exit on error

# Configuration
STACK_NAME="friends-app-stack"
TEMPLATE_FILE="infrastructure/dynamodb-stack.yaml"
SEED_DATA_FILE="infrastructure/seed-data.json"
REGION="${AWS_REGION:-us-east-1}"
ENVIRONMENT="${ENVIRONMENT:-dev}"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}===================================${NC}"
echo -e "${BLUE}DynamoDB Stack Deployment Script${NC}"
echo -e "${BLUE}===================================${NC}\n"

# Validate AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo -e "${RED}Error: AWS CLI is not installed${NC}"
    echo "Install it from: https://aws.amazon.com/cli/"
    exit 1
fi

# Validate AWS credentials
echo -e "${BLUE}Validating AWS credentials...${NC}"
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}Error: AWS credentials not configured${NC}"
    echo "Run: aws configure"
    exit 1
fi
echo -e "${GREEN}✓ AWS credentials validated${NC}\n"

# Deploy CloudFormation stack
echo -e "${BLUE}Deploying CloudFormation stack: ${STACK_NAME}${NC}"
echo "Region: ${REGION}"
echo "Environment: ${ENVIRONMENT}"
echo ""

aws cloudformation deploy \
    --template-file "${TEMPLATE_FILE}" \
    --stack-name "${STACK_NAME}" \
    --parameter-overrides \
        Environment="${ENVIRONMENT}" \
    --region "${REGION}" \
    --no-fail-on-empty-changeset \
    --capabilities CAPABILITY_IAM

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Stack deployed successfully${NC}\n"
else
    echo -e "${RED}✗ Stack deployment failed${NC}"
    exit 1
fi

# Get table name from stack outputs
echo -e "${BLUE}Retrieving table name...${NC}"
TABLE_NAME=$(aws cloudformation describe-stacks \
    --stack-name "${STACK_NAME}" \
    --region "${REGION}" \
    --query "Stacks[0].Outputs[?OutputKey=='TableName'].OutputValue" \
    --output text)

if [ -z "${TABLE_NAME}" ]; then
    echo -e "${RED}Error: Could not retrieve table name from stack outputs${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Table name: ${TABLE_NAME}${NC}\n"

# Wait for table to be active
echo -e "${BLUE}Waiting for table to be active...${NC}"
aws dynamodb wait table-exists \
    --table-name "${TABLE_NAME}" \
    --region "${REGION}"
echo -e "${GREEN}✓ Table is active${NC}\n"

# Check if seed data should be loaded
read -p "Load seed data into the table? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}Loading seed data...${NC}"

    # Read seed data and insert each item
    jq -c '.[]' "${SEED_DATA_FILE}" | while read -r item; do
        aws dynamodb put-item \
            --table-name "${TABLE_NAME}" \
            --item "${item}" \
            --region "${REGION}" \
            --no-cli-pager
    done

    echo -e "${GREEN}✓ Seed data loaded successfully${NC}\n"

    # Show item count
    ITEM_COUNT=$(aws dynamodb scan \
        --table-name "${TABLE_NAME}" \
        --region "${REGION}" \
        --select "COUNT" \
        --query "Count" \
        --output text)
    echo -e "${GREEN}Total items in table: ${ITEM_COUNT}${NC}\n"
fi

# Display stack outputs
echo -e "${BLUE}Stack Outputs:${NC}"
aws cloudformation describe-stacks \
    --stack-name "${STACK_NAME}" \
    --region "${REGION}" \
    --query "Stacks[0].Outputs[*].[OutputKey,OutputValue]" \
    --output table

echo ""
echo -e "${GREEN}===================================${NC}"
echo -e "${GREEN}Deployment Complete!${NC}"
echo -e "${GREEN}===================================${NC}"
echo ""
echo "Stack Name: ${STACK_NAME}"
echo "Table Name: ${TABLE_NAME}"
echo "Region: ${REGION}"
echo ""
echo "Useful commands:"
echo "  - View items: aws dynamodb scan --table-name ${TABLE_NAME} --region ${REGION}"
echo "  - Delete stack: aws cloudformation delete-stack --stack-name ${STACK_NAME} --region ${REGION}"
echo ""
