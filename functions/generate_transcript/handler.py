from functions.generate_transcript.index import generate_transcript
import json

def handler(event, _):
    print(event)
    try:
        transcript_input = event['transcript_input']
        game_id = transcript_input['game_id']        
        page_number = transcript_input.get('page_number', 1)
        period = transcript_input.get('period', 1)        
    except KeyError as e:
        print(e)
        return {
            "statusCode": 400,
            "body": json.dumps({"message": f"missing {e}"})
        }
    execution_id = event['execution_id'].split(":")
    transaction_id = execution_id[-1]
    transcript_results = generate_transcript(game_id, period, page_number, transaction_id)
    if len(transcript_results) == 0:
        response = {
            "data": transcript_results,
            "statusCode": 404
        }
    else:
        response = transcript_results
    return response
