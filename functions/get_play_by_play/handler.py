from .index import get_play_by_play
import json
from aws_lambda_powertools import Logger


logger = Logger()


@logger.inject_lambda_context(log_event=True)
def handler(event, _):
    try:
        game_id =  event['pathParameters']['game_id']
        query_parameters = event.get('queryStringParameters', {})
        if not query_parameters:
            query_parameters = {}
        page_number = query_parameters.get('page_number', 1)
        period = query_parameters.get('period', 1)
    except KeyError as e:
        logger.error("Missing game_id in path parameters")
        body = json.dumps({"message": "missing game_id"})
        return {
            "statusCode": 400,
            "body": body
        }
    pbp_results = get_play_by_play(game_id, period, page_number)
    if len(pbp_results) == 0:
        response = {
            "page": 0,
            "per_page": 10,
            "total": 0,
            "total_pages": 0,
            "data": pbp_results,
            "statusCode": 404
        }
    else:
        response = pbp_results
    return response
