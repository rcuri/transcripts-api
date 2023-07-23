from functions.get_transcript_status.index import get_transcript_status
import json
from aws_lambda_powertools import Logger


logger = Logger()


@logger.inject_lambda_context(log_event=True)
def handler(event, _):
    try:
        transcript_id =  event['pathParameters']['transcript_id']
    except KeyError as e:
        logger.error("Missing transcript_id in path parameters")
        body = json.dumps({"message": "missing transcript_id"})
        return {
            "statusCode": 400,
            "body": body
        }
    transcript_results = get_transcript_status(transcript_id)
    return transcript_results
