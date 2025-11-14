# DynamoDB Infrastructure for Friends App

This directory contains AWS CloudFormation templates and deployment scripts to provision a DynamoDB table for the Friends application.

## 📋 Overview

The CloudFormation template creates a DynamoDB table optimized for the Friends app with:

- **Primary Key**: `id` (String) - Unique identifier for each friend
- **Attributes**:
  - `friendName` (String) - Friend's name
  - `phoneNumbers` (List of Maps) - Array of phone number objects
  - `createdAt` (Number) - Timestamp
  - `updatedAt` (Number) - Last modified timestamp
- **Global Secondary Indexes**:
  - `FriendNameIndex` - Query friends by name
  - `CreatedAtIndex` - Sort/filter by creation date
- **Features**:
  - Pay-per-request billing (no capacity planning)
  - Point-in-time recovery enabled
  - KMS encryption at rest
  - DynamoDB Streams for change data capture

## 🗂 Files

- `dynamodb-stack.yaml` - CloudFormation template defining the DynamoDB table
- `seed-data.json` - Sample friend records in DynamoDB JSON format
- `deploy.sh` - Automated deployment script

## 🚀 Quick Start

### Prerequisites

1. **AWS CLI** installed and configured:

   ```bash
   aws --version
   aws configure
   ```

2. **jq** (for JSON processing in deploy script):

   ```bash
   # macOS
   brew install jq

   # Linux
   sudo apt-get install jq
   ```

3. **AWS Credentials** with permissions for:
   - CloudFormation (create/update/delete stacks)
   - DynamoDB (create tables, put items, scan)
   - KMS (for encryption)

### Deploy the Stack

```bash
# Make the script executable
chmod +x infrastructure/deploy.sh

# Deploy with default settings (dev environment, us-east-1)
./infrastructure/deploy.sh

# Or specify environment and region
ENVIRONMENT=prod AWS_REGION=us-west-2 ./infrastructure/deploy.sh
```

The script will:

1. Validate AWS credentials
2. Deploy the CloudFormation stack
3. Wait for the table to be active
4. Prompt to load seed data
5. Display stack outputs

## 📝 Manual Deployment

If you prefer manual deployment:

### 1. Deploy CloudFormation Stack

```bash
aws cloudformation deploy \
  --template-file infrastructure/dynamodb-stack.yaml \
  --stack-name friends-app-stack \
  --parameter-overrides Environment=dev \
  --region us-east-1
```

### 2. Get Table Name

```bash
TABLE_NAME=$(aws cloudformation describe-stacks \
  --stack-name friends-app-stack \
  --query "Stacks[0].Outputs[?OutputKey=='TableName'].OutputValue" \
  --output text)

echo $TABLE_NAME
```

### 3. Load Seed Data

```bash
# Load all items from seed-data.json
jq -c '.[]' infrastructure/seed-data.json | while read item; do
  aws dynamodb put-item \
    --table-name $TABLE_NAME \
    --item "$item"
done
```

### 4. Verify Data

```bash
# Count items
aws dynamodb scan \
  --table-name $TABLE_NAME \
  --select "COUNT"

# View all items
aws dynamodb scan \
  --table-name $TABLE_NAME
```

## 🔍 CloudFormation Parameters

| Parameter     | Default             | Description                           |
| ------------- | ------------------- | ------------------------------------- |
| `TableName`   | `friends-app-table` | Base name for the DynamoDB table      |
| `Environment` | `dev`               | Environment suffix (dev/staging/prod) |

Final table name format: `{TableName}-{Environment}` (e.g., `friends-app-table-dev`)

## 📊 DynamoDB Schema Details

### Item Structure (TypeScript Mapping)

```typescript
{
  id: string,              // Partition key - "friend-001"
  friendName: string,      // "Will"
  phoneNumbers: [          // List of phone number objects
    {
      id: number,          // 101
      type: 'home' | 'work' | 'mobile',
      number: string       // "555-1234"
    }
  ],
  createdAt: number,       // Unix timestamp in milliseconds
  updatedAt: number        // Unix timestamp in milliseconds
}
```

### DynamoDB JSON Format

DynamoDB uses typed JSON with attribute markers:

- `S` = String
- `N` = Number (stored as string)
- `L` = List
- `M` = Map
- `BOOL` = Boolean

Example item:

```json
{
  "id": { "S": "friend-001" },
  "friendName": { "S": "Will" },
  "phoneNumbers": {
    "L": [
      {
        "M": {
          "id": { "N": "101" },
          "type": { "S": "mobile" },
          "number": { "S": "123-456-7890" }
        }
      }
    ]
  }
}
```

### Global Secondary Indexes

**FriendNameIndex**

- Partition Key: `friendName`
- Use case: Query all friends with a specific name
- Query example:
  ```bash
  aws dynamodb query \
    --table-name $TABLE_NAME \
    --index-name FriendNameIndex \
    --key-condition-expression "friendName = :name" \
    --expression-attribute-values '{":name":{"S":"Will"}}'
  ```

**CreatedAtIndex**

- Partition Key: `friendName`
- Sort Key: `createdAt`
- Use case: Get friends sorted by creation date, filter by name
- Query example:
  ```bash
  aws dynamodb query \
    --table-name $TABLE_NAME \
    --index-name CreatedAtIndex \
    --key-condition-expression "friendName = :name AND createdAt > :timestamp" \
    --expression-attribute-values '{":name":{"S":"Will"},":timestamp":{"N":"1699392000000"}}'
  ```

## 🛠 Common Operations

### Add a New Friend

```bash
aws dynamodb put-item \
  --table-name $TABLE_NAME \
  --item '{
    "id": {"S": "friend-006"},
    "friendName": {"S": "John"},
    "phoneNumbers": {
      "L": [
        {
          "M": {
            "id": {"N": "601"},
            "type": {"S": "mobile"},
            "number": {"S": "555-000-1111"}
          }
        }
      ]
    },
    "createdAt": {"N": "'$(date +%s)000'"},
    "updatedAt": {"N": "'$(date +%s)000'"}
  }'
```

### Get a Friend by ID

```bash
aws dynamodb get-item \
  --table-name $TABLE_NAME \
  --key '{"id": {"S": "friend-001"}}'
```

### Update a Friend

```bash
aws dynamodb update-item \
  --table-name $TABLE_NAME \
  --key '{"id": {"S": "friend-001"}}' \
  --update-expression "SET friendName = :name, updatedAt = :timestamp" \
  --expression-attribute-values '{
    ":name": {"S": "William"},
    ":timestamp": {"N": "'$(date +%s)000'"}
  }'
```

### Delete a Friend

```bash
aws dynamodb delete-item \
  --table-name $TABLE_NAME \
  --key '{"id": {"S": "friend-001"}}'
```

### Query by Name (using GSI)

```bash
aws dynamodb query \
  --table-name $TABLE_NAME \
  --index-name FriendNameIndex \
  --key-condition-expression "friendName = :name" \
  --expression-attribute-values '{":name": {"S": "Jane"}}'
```

## 💰 Cost Considerations

- **Billing Mode**: PAY_PER_REQUEST (on-demand)
  - No upfront costs
  - Pay per read/write request
  - Good for unpredictable or low-traffic workloads
- **Pricing** (approximate, us-east-1):

  - Write: $1.25 per million requests
  - Read: $0.25 per million requests
  - Storage: $0.25 per GB-month
  - Point-in-time recovery: Additional cost

- **Alternative**: Switch to PROVISIONED billing if you have predictable traffic patterns

## 🗑 Cleanup

### Delete the Stack (removes table and all data)

```bash
aws cloudformation delete-stack \
  --stack-name friends-app-stack \
  --region us-east-1
```

### Delete Just the Data (keep table)

```bash
# Scan and delete all items
aws dynamodb scan --table-name $TABLE_NAME \
  --attributes-to-get "id" \
  --query "Items[*]" \
  --output json | \
  jq -c '.[]' | while read key; do
    aws dynamodb delete-item \
      --table-name $TABLE_NAME \
      --key "$key"
  done
```

## 🔗 Integration with Angular App

To connect your Angular app to DynamoDB, you'll need:

1. **AWS SDK for JavaScript v3**:

   ```bash
   npm install @aws-sdk/client-dynamodb @aws-sdk/lib-dynamodb
   ```

2. **Update Friend Service** to use DynamoDB:

   ```typescript
   import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
   import { DynamoDBDocumentClient, ScanCommand, PutCommand } from '@aws-sdk/lib-dynamodb';

   const client = new DynamoDBClient({ region: 'us-east-1' });
   const docClient = DynamoDBDocumentClient.from(client);

   async getFriends() {
     const command = new ScanCommand({ TableName: 'friends-app-table-dev' });
     const response = await docClient.send(command);
     return response.Items;
   }
   ```

3. **Authentication**: Use AWS Cognito or IAM credentials
4. **API Gateway**: Consider creating a REST API in front of DynamoDB for security

## 📚 Additional Resources

- [AWS DynamoDB Developer Guide](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/)
- [CloudFormation DynamoDB Reference](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-resource-dynamodb-table.html)
- [DynamoDB Best Practices](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/best-practices.html)
- [AWS SDK for JavaScript v3](https://docs.aws.amazon.com/AWSJavaScriptSDK/v3/latest/)

## 🐛 Troubleshooting

### Stack deployment fails

```bash
# Check stack events
aws cloudformation describe-stack-events \
  --stack-name friends-app-stack \
  --max-items 10
```

### Can't load seed data

- Verify table exists: `aws dynamodb list-tables`
- Check IAM permissions: `dynamodb:PutItem`
- Validate JSON format: `jq . infrastructure/seed-data.json`

### Query returns no results

- Verify GSI is active (can take a few minutes after creation)
- Check attribute names and types match exactly
- Use `--debug` flag with AWS CLI for detailed error messages

---

**Questions?** Open an issue or check AWS CloudFormation/DynamoDB documentation.
