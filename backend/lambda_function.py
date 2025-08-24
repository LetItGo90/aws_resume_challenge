import json
import boto3
import os

# Don't connect to DynamoDB at import time
def get_dynamodb():
    if os.environ.get('AWS_SAM_LOCAL'):
        return boto3.resource('dynamodb', endpoint_url='http://localhost:8000')
    else:
        return boto3.resource('dynamodb')

def lambda_handler(event, context):
    # Connect to DynamoDB inside the function
    dynamodb = get_dynamodb()
    table = dynamodb.Table('visitor-counter')
    
    try:
        response = table.get_item(Key={'id': 'visitor_count'})
        if 'Item' in response:
            count = response['Item']['count'] + 1
        else:
            count = 1
        
        table.put_item(Item={'id': 'visitor_count', 'count': count})
        
        return {
            'statusCode': 200,
            'headers': {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type',
                'Access-Control-Allow-Methods': 'GET'
            },
            'body': json.dumps({'visitor_count': count})
        }
    except Exception as e:
        return {
            'statusCode': 500,
            'headers': {
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({'error': str(e)})
        }