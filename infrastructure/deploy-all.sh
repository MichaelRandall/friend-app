#!/bin/bash
set -e  # Exit on error

# Configuration
REGION="${AWS_REGION:-us-east-1}"
ENVIRONMENT="${ENVIRONMENT:-dev}"

# Stack names
DB_STACK="friends-app-stack"
LAMBDA_STACK="friends-lambda-stack"
API_STACK="friends-api-stack"

# Template files
DB_TEMPLATE="infrastructure/dynamodb-stack.yaml"
LAMBDA_TEMPLATE="infrastructure/02-lambda-stack.yaml"
API_TEMPLATE="infrastructure/03-api-gateway-stack.yaml"
SEED_DATA="infrastructure/seed-data.json"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}===================================${NC}"
echo -e "${BLUE}Friends App - Complete Deployment${NC}"
echo -e "${BLUE}===================================${NC}\n"

# Validate AWS CLI
if ! command -v aws &> /dev/null; then
    echo -e "${RED}Error: AWS CLI is not installed${NC}"
    exit 1
fi

# Validate jq for seed data
if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: jq is not installed (needed for seed data)${NC}"
    echo "Install: brew install jq (macOS) or sudo apt-get install jq (Linux)"
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

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo -e "AWS Account: ${ACCOUNT_ID}"
echo -e "Region: ${REGION}"
echo -e "Environment: ${ENVIRONMENT}\n"

# Function to check stack status
check_stack_exists() {
    aws cloudformation describe-stacks \
        --stack-name "$1" \
        --region "${REGION}" \
        &> /dev/null
    return $?
}

# Function to deploy stack
deploy_stack() {
    local stack_name=$1
    local template=$2
    local params=$3

    echo -e "${BLUE}===================================${NC}"
    echo -e "${BLUE}Deploying: ${stack_name}${NC}"
    echo -e "${BLUE}===================================${NC}\n"

    if check_stack_exists "${stack_name}"; then
        echo -e "${YELLOW}Stack ${stack_name} already exists, updating...${NC}"
    else
        echo -e "${GREEN}Creating new stack ${stack_name}...${NC}"
    fi

    aws cloudformation deploy \
        --template-file "${template}" \
        --stack-name "${stack_name}" \
        --parameter-overrides ${params} \
        --region "${REGION}" \
        --capabilities CAPABILITY_NAMED_IAM \
        --no-fail-on-empty-changeset

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ ${stack_name} deployed successfully${NC}\n"
        return 0
    else
        echo -e "${RED}✗ ${stack_name} deployment failed${NC}"
        return 1
    fi
}

# Function to get stack output
get_output() {
    aws cloudformation describe-stacks \
        --stack-name "$1" \
        --region "${REGION}" \
        --query "Stacks[0].Outputs[?OutputKey=='$2'].OutputValue" \
        --output text 2>/dev/null
}

echo -e "${YELLOW}Deployment will proceed in 3 stages:${NC}"
echo "  1. DynamoDB (database layer)"
echo "  2. Lambda (business logic layer)"
echo "  3. API Gateway (API layer)"
echo ""

read -p "Continue with deployment? (Y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Nn]$ ]]; then
    echo -e "${YELLOW}Deployment cancelled${NC}"
    exit 0
fi

# ==================================
# STAGE 1: Deploy DynamoDB
# ==================================
if ! deploy_stack "${DB_STACK}" "${DB_TEMPLATE}" "Environment=${ENVIRONMENT}"; then
    echo -e "${RED}Failed to deploy DynamoDB stack. Aborting.${NC}"
    exit 1
fi

# Wait for table to be active
TABLE_NAME=$(get_output "${DB_STACK}" "TableName")
echo -e "${BLUE}Waiting for DynamoDB table to be active...${NC}"
aws dynamodb wait table-exists --table-name "${TABLE_NAME}" --region "${REGION}"
echo -e "${GREEN}✓ Table is active: ${TABLE_NAME}${NC}\n"

# Optionally seed data
if [ -f "${SEED_DATA}" ]; then
    echo -e "${BLUE}Seed data file found${NC}"
    read -p "Load seed data into DynamoDB? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}Loading seed data...${NC}"

        ITEM_COUNT=0
        while read -r item; do
            aws dynamodb put-item \
                --table-name "${TABLE_NAME}" \
                --item "${item}" \
                --region "${REGION}" \
                --no-cli-pager
            ((ITEM_COUNT++))
        done < <(jq -c '.[]' "${SEED_DATA}")

        echo -e "${GREEN}✓ Loaded ${ITEM_COUNT} items${NC}\n"
    fi
fi

# ==================================
# STAGE 2: Deploy Lambda Functions
# ==================================
if ! deploy_stack "${LAMBDA_STACK}" "${LAMBDA_TEMPLATE}" "Environment=${ENVIRONMENT} DatabaseStackName=${DB_STACK}"; then
    echo -e "${RED}Failed to deploy Lambda stack. Aborting.${NC}"
    exit 1
fi

# ==================================
# STAGE 3: Deploy API Gateway
# ==================================
if ! deploy_stack "${API_STACK}" "${API_TEMPLATE}" "Environment=${ENVIRONMENT} LambdaStackName=${LAMBDA_STACK}"; then
    echo -e "${RED}Failed to deploy API Gateway stack. Aborting.${NC}"
    exit 1
fi

# ==================================
# Display Summary
# ==================================
echo -e "${GREEN}===================================${NC}"
echo -e "${GREEN}✓ Deployment Complete!${NC}"
echo -e "${GREEN}===================================${NC}\n"

API_ENDPOINT=$(get_output "${API_STACK}" "ApiEndpoint")

echo "Stack Outputs:"
echo "  DynamoDB Table: ${TABLE_NAME}"
echo "  API Endpoint: ${API_ENDPOINT}"
echo ""
echo "Test your API:"
echo "  Get all friends:"
echo "    curl ${API_ENDPOINT}/friends"
echo ""
echo "  Get single friend:"
echo "    curl ${API_ENDPOINT}/friends/friend-001"
echo ""
echo "  Create friend:"
echo "    curl -X POST ${API_ENDPOINT}/friends \\"
echo "      -H 'Content-Type: application/json' \\"
echo "      -d '{\"friendName\":\"Bob\",\"phoneNumbers\":[{\"id\":123,\"type\":\"mobile\",\"number\":\"555-0000\"}]}'"
echo ""
echo "  Update friend:"
echo "    curl -X PUT ${API_ENDPOINT}/friends/friend-001 \\"
echo "      -H 'Content-Type: application/json' \\"
echo "      -d '{\"friendName\":\"William\"}'"
echo ""
echo "  Delete friend:"
echo "    curl -X DELETE ${API_ENDPOINT}/friends/friend-001"
echo ""
echo "Stack Management:"
echo "  View stacks: aws cloudformation list-stacks --region ${REGION}"
echo "  Teardown: ./infrastructure/teardown.sh"
echo ""
