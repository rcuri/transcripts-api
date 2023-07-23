import json
import os
from aws_lambda_powertools import Logger
from boto3 import client
from uuid import uuid4


logger = Logger()
sqs_client = client('sqs')
sqs_url = os.environ.get('TRANSCRIPTS_SQS_URL')

def submit_transcript_request(game_id, period, page_number=1):
    transcript_id = str(uuid4())
    input_dict = {
        "game_id": game_id,
        "period": period,
        "page_number": page_number,
        "transcript_id": transcript_id,
    }
    logger.info({
        "sqs_message_body": input_dict,
        "sqs_message_group_id": "submit_transcripts"
    })
    json_input_dict = json.dumps(input_dict)
    send_message_response = sqs_client.send_message(
        QueueUrl=sqs_url,
        MessageBody=json_input_dict,
        MessageGroupId="submit_transcripts"
    )
    logger.info({"sqs_send_message_response": send_message_response})
    body = {
        "transcript_id": transcript_id
    }
    output = json.dumps(body)
    response = {
        "statusCode": 200,
        "body": output
    }
    return response
    