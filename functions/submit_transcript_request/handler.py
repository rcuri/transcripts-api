from index import submit_transcript_request
import json
from aws_lambda_powertools import Logger


logger = Logger()


@logger.inject_lambda_context(log_event=True)
def handler(event, _):
    try:
        body = json.loads(event['body'])
        game_id = body['game_id']        
        page_number = body.get('page_number', 1)
        period = body.get('period', 1)
    except KeyError as e:
        logger.error("Missing game_id in request body")
        body = json.dumps({"message": "missing game_id"})
        return {
            "statusCode": 400,
            "body": body
        }
    transcript_results = submit_transcript_request(game_id, period, page_number)
    return transcript_results
