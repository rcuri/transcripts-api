from boto3 import client
import os
import psycopg2
import json
from aws_lambda_powertools import Logger
from database.config import DatabaseConfig


stage = os.environ.get('STAGE', 'dev')
logger = Logger()
sfn_client = client('stepfunctions')
state_machine_arn = os.environ.get('TRANSCRIPTS_STATE_MACHINE')
db_config = DatabaseConfig(stage)


@logger.inject_lambda_context(log_event=True)
def process_sqs_queue(event, _):
    logger.info({
        "event": event,
        "message": "Retrieved a message from transcripts_queue"
    })
    transcript_json_str = event['Records'][0]['body']
    transcript_input = json.loads(event['Records'][0]['body'])
    print(transcript_input)
    transcript_id = transcript_input['transcript_id']
    game_id = transcript_input['game_id']
    period = transcript_input['period']
    page_number = transcript_input['page_number']
    sfn_execution = sfn_client.start_execution(
        stateMachineArn=state_machine_arn,
        input=transcript_json_str,
        name=transcript_input['transcript_id']
    )
    execution_arn = sfn_execution['executionArn']
    logger.info({
        "message": "Succesfully started state machine execution",
        "state_machine_arn": state_machine_arn,
        "execution_arn": execution_arn
    })
    status = "IN_PROGRESS"
    transaction_id = execution_arn.split(":")[-1]
    connection = psycopg2.connect(
        user=db_config.POSTGRES_USER,
        password=db_config.POSTGRES_PW,
        host=db_config.POSTGRES_URL,
        database=db_config.POSTGRES_DB,
        port=db_config.POSTGRES_PORT
    )
    query = """
        INSERT INTO 
        transcript(transaction_id, transaction_status, game_id, period, page_number)
        VALUES ((%s), (%s), (%s), (%s), (%s));
    """
    cursor = connection.cursor()
    cursor.execute(query, (transcript_id, status, game_id, period, page_number))
    cursor.close()
    connection.commit()
    logger.info("Finished processing SQS message")
    