from functions.process_sqs_queue.index import process_sqs_queue
from aws_lambda_powertools import Logger


logger = Logger()


@logger.inject_lambda_context(log_event=True)
def handler(event, context):
    return process_sqs_queue(event, context) 