import json
import boto3

def lambda_handler(event, context):
    # MUST specify region for DynamoDB
    dynamodb = boto3.resource('dynamodb', region_name='us-east-1')
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