from functions.update_generate_transcript_status.index import update_generate_transcript_status
from aws_lambda_powertools import Logger


logger = Logger()


@logger.inject_lambda_context(log_event=True)
def handler(event, context):
    return update_generate_transcript_status(event, context) 