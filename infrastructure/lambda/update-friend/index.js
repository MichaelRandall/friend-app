const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, UpdateCommand, GetCommand } = require('@aws-sdk/lib-dynamodb');

const client = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(client);

const TABLE_NAME = process.env.TABLE_NAME;

exports.handler = async (event) => {
  console.log('Update Friend - Event:', JSON.stringify(event, null, 2));

  const friendId = event.pathParameters?.id;

  if (!friendId) {
    return {
      statusCode: 400,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
      body: JSON.stringify({
        error: 'Missing friend ID'
      })
    };
  }

  let body;
  try {
    body = JSON.parse(event.body || '{}');
  } catch (error) {
    return {
      statusCode: 400,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
      body: JSON.stringify({
        error: 'Invalid JSON in request body'
      })
    };
  }

  // Check if friend exists
  try {
    const getCommand = new GetCommand({
      TableName: TABLE_NAME,
      Key: { id: friendId }
    });

    const existingFriend = await docClient.send(getCommand);

    if (!existingFriend.Item) {
      return {
        statusCode: 404,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
        body: JSON.stringify({
          error: 'Friend not found'
        })
      };
    }

    // Build update expression dynamically
    const updateExpressions = [];
    const expressionAttributeNames = {};
    const expressionAttributeValues = {};

    if (body.friendName) {
      updateExpressions.push('#friendName = :friendName');
      expressionAttributeNames['#friendName'] = 'friendName';
      expressionAttributeValues[':friendName'] = body.friendName;
    }

    if (body.phoneNumbers) {
      updateExpressions.push('#phoneNumbers = :phoneNumbers');
      expressionAttributeNames['#phoneNumbers'] = 'phoneNumbers';
      expressionAttributeValues[':phoneNumbers'] = body.phoneNumbers;
    }

    // Always update timestamp
    updateExpressions.push('#updatedAt = :updatedAt');
    expressionAttributeNames['#updatedAt'] = 'updatedAt';
    expressionAttributeValues[':updatedAt'] = Date.now();

    if (updateExpressions.length === 1) {
      // Only updatedAt, no actual changes
      return {
        statusCode: 400,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
        body: JSON.stringify({
          error: 'No valid fields to update'
        })
      };
    }

    const updateCommand = new UpdateCommand({
      TableName: TABLE_NAME,
      Key: { id: friendId },
      UpdateExpression: `SET ${updateExpressions.join(', ')}`,
      ExpressionAttributeNames: expressionAttributeNames,
      ExpressionAttributeValues: expressionAttributeValues,
      ReturnValues: 'ALL_NEW'
    });

    const response = await docClient.send(updateCommand);

    return {
      statusCode: 200,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type',
        'Access-Control-Allow-Methods': 'PUT,OPTIONS'
      },
      body: JSON.stringify(response.Attributes)
    };
  } catch (error) {
    console.error('Error:', error);
    return {
      statusCode: 500,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
      body: JSON.stringify({
        error: 'Failed to update friend',
        message: error.message
      })
    };
  }
};
