import json
import boto3
from decimal import Decimal

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('resume-visitor-count')

def lambda_handler(event, context):
    try:
        # Get current count
        response = table.get_item(Key={'id': 'visitor_count'})
        
        if 'Item' in response:
            # Convert Decimal to int
            count = int(response['Item']['count'])
        else:
            count = 0
        
        # Increment count
        new_count = count + 1
        
        # Update database
        table.put_item(Item={
            'id': 'visitor_count',
            'count': new_count
        })
        
        # Return the count (now it's an int, not Decimal)
        return {
            'statusCode': 200,
            'headers': {
                'Access-Control-Allow-Origin': 'https://austin-mundy-resume.com',
                'Access-Control-Allow-Headers': 'Content-Type',
                'Access-Control-Allow-Methods': 'GET'
            },
            'body': json.dumps({'count': new_count})
        }
    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {
                'Access-Control-Allow-Origin': 'https://austin-mundy-resume.com'
            },
            'body': json.dumps({'message': 'Internal server error'})
        }