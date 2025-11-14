#!/bin/bash
set -e  # Exit on error

# Configuration
REGION="${AWS_REGION:-us-east-1}"
ENVIRONMENT="${ENVIRONMENT:-dev}"

# Stack names (reverse order for deletion)
API_STACK="friends-api-stack"
LAMBDA_STACK="friends-lambda-stack"
DB_STACK="friends-app-stack"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${RED}===================================${NC}"
echo -e "${RED}AWS Stack Teardown Script${NC}"
echo -e "${RED}===================================${NC}\n"

# Validate AWS CLI
if ! command -v aws &> /dev/null; then
    echo -e "${RED}Error: AWS CLI is not installed${NC}"
    exit 1
fi

# Validate AWS credentials
echo -e "${BLUE}Validating AWS credentials...${NC}"
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}Error: AWS credentials not configured${NC}"
    exit 1
fi
echo -e "${GREEN}✓ AWS credentials validated${NC}\n"

# Display current account info
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo -e "${YELLOW}AWS Account: ${ACCOUNT_ID}${NC}"
echo -e "${YELLOW}Region: ${REGION}${NC}"
echo -e "${YELLOW}Environment: ${ENVIRONMENT}${NC}\n"

# Function to check if stack exists
stack_exists() {
    aws cloudformation describe-stacks \
        --stack-name "$1" \
        --region "${REGION}" \
        &> /dev/null
    return $?
}

# Function to get stack status
get_stack_status() {
    aws cloudformation describe-stacks \
        --stack-name "$1" \
        --region "${REGION}" \
        --query "Stacks[0].StackStatus" \
        --output text 2>/dev/null || echo "DOES_NOT_EXIST"
}

# Check which stacks exist
echo -e "${BLUE}Checking for existing stacks...${NC}\n"

STACKS_TO_DELETE=()

if stack_exists "${API_STACK}"; then
    STATUS=$(get_stack_status "${API_STACK}")
    echo -e "  ${GREEN}✓${NC} ${API_STACK} (${STATUS})"
    STACKS_TO_DELETE+=("${API_STACK}")
else
    echo -e "  ${YELLOW}○${NC} ${API_STACK} (does not exist)"
fi

if stack_exists "${LAMBDA_STACK}"; then
    STATUS=$(get_stack_status "${LAMBDA_STACK}")
    echo -e "  ${GREEN}✓${NC} ${LAMBDA_STACK} (${STATUS})"
    STACKS_TO_DELETE+=("${LAMBDA_STACK}")
else
    echo -e "  ${YELLOW}○${NC} ${LAMBDA_STACK} (does not exist)"
fi

if stack_exists "${DB_STACK}"; then
    STATUS=$(get_stack_status "${DB_STACK}")
    echo -e "  ${GREEN}✓${NC} ${DB_STACK} (${STATUS})"
    STACKS_TO_DELETE+=("${DB_STACK}")
else
    echo -e "  ${YELLOW}○${NC} ${DB_STACK} (does not exist)"
fi

echo ""

# Exit if no stacks to delete
if [ ${#STACKS_TO_DELETE[@]} -eq 0 ]; then
    echo -e "${YELLOW}No stacks found to delete. Exiting.${NC}"
    exit 0
fi

# Offer backup option for DynamoDB
if stack_exists "${DB_STACK}"; then
    echo -e "${YELLOW}⚠️  WARNING: DynamoDB stack contains data!${NC}\n"
    read -p "Create backup before deletion? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}Creating DynamoDB backup...${NC}"

        # Get table name
        TABLE_NAME=$(aws cloudformation describe-stacks \
            --stack-name "${DB_STACK}" \
            --region "${REGION}" \
            --query "Stacks[0].Outputs[?OutputKey=='TableName'].OutputValue" \
            --output text 2>/dev/null)

        if [ -n "${TABLE_NAME}" ]; then
            BACKUP_NAME="friends-backup-$(date +%Y%m%d-%H%M%S)"

            aws dynamodb create-backup \
                --table-name "${TABLE_NAME}" \
                --backup-name "${BACKUP_NAME}" \
                --region "${REGION}" \
                &> /dev/null

            if [ $? -eq 0 ]; then
                echo -e "${GREEN}✓ Backup created: ${BACKUP_NAME}${NC}\n"
            else
                echo -e "${RED}✗ Backup failed${NC}\n"
            fi
        else
            echo -e "${YELLOW}Could not retrieve table name for backup${NC}\n"
        fi
    fi
fi

# Final confirmation
echo -e "${YELLOW}===================================${NC}"
echo -e "${RED}⚠️  DESTRUCTIVE OPERATION${NC}"
echo -e "${YELLOW}===================================${NC}\n"
echo "The following stacks will be DELETED:"
for stack in "${STACKS_TO_DELETE[@]}"; do
    echo "  - ${stack}"
done
echo ""
echo -e "${RED}This action cannot be undone!${NC}\n"

read -p "Are you absolutely sure you want to delete these stacks? (yes/NO): " -r
echo
if [[ ! $REPLY =~ ^yes$ ]]; then
    echo -e "${YELLOW}Deletion cancelled.${NC}"
    exit 0
fi

# Delete stacks in reverse dependency order
echo -e "\n${BLUE}===================================${NC}"
echo -e "${BLUE}Starting Stack Deletion${NC}"
echo -e "${BLUE}===================================${NC}\n"

# Function to delete a stack
delete_stack() {
    local stack_name=$1

    if ! stack_exists "${stack_name}"; then
        echo -e "${YELLOW}Stack ${stack_name} does not exist, skipping${NC}"
        return 0
    fi

    echo -e "${BLUE}Deleting ${stack_name}...${NC}"

    aws cloudformation delete-stack \
        --stack-name "${stack_name}" \
        --region "${REGION}"

    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ Failed to initiate deletion of ${stack_name}${NC}"
        return 1
    fi

    echo "  Waiting for deletion to complete..."

    aws cloudformation wait stack-delete-complete \
        --stack-name "${stack_name}" \
        --region "${REGION}"

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ ${stack_name} deleted successfully${NC}\n"
        return 0
    else
        # Check if stack still exists or failed
        STATUS=$(get_stack_status "${stack_name}")
        if [ "${STATUS}" == "DOES_NOT_EXIST" ]; then
            echo -e "${GREEN}✓ ${stack_name} deleted${NC}\n"
            return 0
        else
            echo -e "${RED}✗ ${stack_name} deletion failed (Status: ${STATUS})${NC}"

            # Show recent events
            echo -e "${YELLOW}Recent stack events:${NC}"
            aws cloudformation describe-stack-events \
                --stack-name "${stack_name}" \
                --region "${REGION}" \
                --max-items 5 \
                --query 'StackEvents[*].[Timestamp,ResourceStatus,ResourceType,ResourceStatusReason]' \
                --output table

            return 1
        fi
    fi
}

# Delete stacks in order
FAILED_STACKS=()

# 1. API Gateway (no dependencies)
if [[ " ${STACKS_TO_DELETE[@]} " =~ " ${API_STACK} " ]]; then
    if ! delete_stack "${API_STACK}"; then
        FAILED_STACKS+=("${API_STACK}")
    fi
fi

# 2. Lambda (depends on DynamoDB exports)
if [[ " ${STACKS_TO_DELETE[@]} " =~ " ${LAMBDA_STACK} " ]]; then
    if ! delete_stack "${LAMBDA_STACK}"; then
        FAILED_STACKS+=("${LAMBDA_STACK}")
    fi
fi

# 3. DynamoDB (bottom of dependency chain)
if [[ " ${STACKS_TO_DELETE[@]} " =~ " ${DB_STACK} " ]]; then
    if ! delete_stack "${DB_STACK}"; then
        FAILED_STACKS+=("${DB_STACK}")
    fi
fi

# Summary
echo -e "${BLUE}===================================${NC}"
echo -e "${BLUE}Teardown Summary${NC}"
echo -e "${BLUE}===================================${NC}\n"

if [ ${#FAILED_STACKS[@]} -eq 0 ]; then
    echo -e "${GREEN}✓ All stacks deleted successfully!${NC}\n"
    echo "Resources removed:"
    echo "  - API Gateway endpoint"
    echo "  - Lambda functions"
    echo "  - DynamoDB table"
    echo "  - IAM roles and policies"
    echo "  - CloudWatch log groups"
    exit 0
else
    echo -e "${RED}✗ Some stacks failed to delete:${NC}"
    for stack in "${FAILED_STACKS[@]}"; do
        echo "  - ${stack}"
    done
    echo ""
    echo "Troubleshooting tips:"
    echo "  1. Check stack events: aws cloudformation describe-stack-events --stack-name STACK_NAME"
    echo "  2. Manually delete resources preventing deletion"
    echo "  3. Force delete: aws cloudformation delete-stack --stack-name STACK_NAME --retain-resources RESOURCE_ID"
    echo ""
    exit 1
fi
