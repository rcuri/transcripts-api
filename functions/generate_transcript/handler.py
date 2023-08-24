from .index import generate_transcript
import json

def handler(event, _):
    try:
        body = json.loads(event['body'])
        game_id = body['game_id']        
        page_number = body.get('page_number', 1)
        period = body.get('period', 1)
    except KeyError as e:
        body = json.dumps({"message": "missing game_id"})
        return {
            "statusCode": 400,
            "body": body
        }
    transcript_results = generate_transcript(game_id, period, page_number)
    if len(transcript_results) == 0:
        response = {
            "data": transcript_results,
            "statusCode": 404
        }
    else:
        response = transcript_results
    return response
