const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, DeleteCommand, GetCommand } = require('@aws-sdk/lib-dynamodb');

const client = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(client);

const TABLE_NAME = process.env.TABLE_NAME;

exports.handler = async (event) => {
  console.log('Delete Friend - Event:', JSON.stringify(event, null, 2));

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

  try {
    // Check if friend exists first
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

    // Delete the friend
    const deleteCommand = new DeleteCommand({
      TableName: TABLE_NAME,
      Key: { id: friendId }
    });

    await docClient.send(deleteCommand);

    return {
      statusCode: 200,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type',
        'Access-Control-Allow-Methods': 'DELETE,OPTIONS'
      },
      body: JSON.stringify({
        message: 'Friend deleted successfully',
        id: friendId
      })
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
        error: 'Failed to delete friend',
        message: error.message
      })
    };
  }
};
