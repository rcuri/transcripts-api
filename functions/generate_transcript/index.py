import psycopg2
import openai
import re
import json
import os
from aws_lambda_powertools import Logger
from database.config import DatabaseConfig


stage = os.environ.get('STAGE', 'dev')
logger = Logger()
db_config = DatabaseConfig(stage)

def generate_system_prompt():
    return 'You are part of an elite team that sits courtside at NBA games and watches NBA games live. Your team is responsible for coming up with what the commentators say as they watch the game live. Tonight\'s commentators are Kevin Harlan and Reggie Miller. Your team has watched all of the games that these announcers have commentated on so you\'re very familiar with how they speak and the pace at which they speak.\nAt the end of the night, your team compiles a transcript of everything your team told the commentators to say while watching the game. After the game, the transcript is compared against play-by-play data for the game and your team is graded based on a couple of factors:\n- How relevant the discussion is to the type of play in event_type_value\n- Casual banter between the announcers sometimes\n- Smooth transitions between consecutive in-game events\n- The time it takes for an announcer to speak matches flow of the game\n- Lines spoken must fill total duration of play\n- Discussion should only talk about the end of the period if event_type_value is "END_OF_PERIOD"\n- Discussion should only talk about the start of the period or game if event_type_value is "START_OF_PERIOD"\n\nEach announcer\'s response must be given in the following format:\n[Estimated time to speak line] Announcer Name: Announcer dialogue\n\nThe first response will always start from zero and the next response\'s time will begin after the first announcer has finished speaking, for example:\n[0:00] Kevin Harlan: And we\'re underway here in Boston as the Celtics host the 76ers.\n[0:04] Reggie Miller: That\'s right Kevin.\n\nEach play will be represented as an event that will be structured as shown below. If a field is missing, assume it is NULL:\n\nevent_type: The type of play that occurred.\nperiod: The period of basketball game.\nlive_time: The time this event occurred in PST.\nplayclock_time: The amount of time remaining in the period.\nhome_description: The description of the play and how the home team was involved in the play.\nvisitor_descriptions: The description of the play and how the visiting team was involved in the play.\nneutral_description: The description of events not related to a specific team.\nscore: The score of the game after the event occurred.\nhome_team: Information regarding the home team in this game.\nvisitor_team: Information regarding the visiting team in this game.\nplayer1_name: The primary player involved in the play.\nplayer1_team: The team of player1.\nplayer2_name: The secondary player involved in the play.\nplayer2_team: The team of player2.\nplayer3_name: The tertiary player involved in the play.\nplayer3_team: The team of player3\n\nSince events provided occur in chronological order, dialogue must transition naturally to the next play.\n\nPlease provide a copy of the announcer\'s transcript.\n'

def generate_transcript_result_line(transaction_id, line_number, speaker_begin_time, speaker_name, line):
    return f"('{transaction_id}', '{line_number}' ,'{speaker_begin_time}', '{speaker_name}', $${line}$$)"


def generate_transcript(event, _):
    transcript_input = event['transcript_input']
    execution_id = event['execution_id'].split(":")
    transaction_id = execution_id[-1]
    page_number = transcript_input['page_number']
    game_id = transcript_input['game_id']
    period = transcript_input['period']

    connection = psycopg2.connect(
        user=db_config.POSTGRES_USER,
        password=db_config.POSTGRES_PW,
        host=db_config.POSTGRES_URL,
        database=db_config.POSTGRES_DB,
        port=db_config.POSTGRES_PORT
    )
    current_offset = (int(page_number) - 1) * 10
    cursor = connection.cursor()
    query = """
        SELECT 
            event_number, 
            event_type_value, 
            period, 
            wc_timestring, 
            pc_timestring, 
            home_description, 
            neutral_description, 
            visitor_description, 
            score, 
            player1_name, 
            team.full_name, 
            player2_name, 
            t2.full_name, 
            player3_name, 
            t3.full_name 
        FROM play_by_play 
        LEFT JOIN team 
            ON play_by_play.player1_team_id = team.team_id 
        LEFT JOIN team t2 
            ON play_by_play.player2_team_id = t2.team_id 
        LEFT JOIN team t3 
            ON play_by_play.player3_team_id = t3.team_id 
        WHERE 
            game_id=(%s) 
            AND period=(%s) 
        ORDER BY event_number ASC 
        LIMIT 10 
        OFFSET (%s);
    """
    cursor.execute(query, (game_id, period, current_offset))
    results = cursor.fetchall()
    if not results:
        logger.info("No play_by_play data found for game_id")
        return []
    cursor.close()
    connection.commit()
    logger.info({"results": results})
    raw_events = []
    for result in results:
        current_record = {
            'event_number': result[0],
            'event_type_value': result[1],
            'period': result[2],
            'wc_timestring': result[3].strftime('%I:%M %p'),
            'pc_timestring': result[4].strftime('%I:%M'),
            'home_description': result[5],
            'neutral_description': result[6],
            'visitor_description': result[7],
            'score': result[8],
            'player1_name': result[9],
            'player1_team_name': result[10],
            'player2_name': result[11],
            'player2_team_name': result[12],
            'player3_name': result[13],
            'player3_team_name': result[14]                                    
        }
        raw_events.append(current_record)
    events = raw_events

    prompt_events = ""
    for event in events:
        for key, val in event.items():
            if val and key not in ["event_msg_type_code", "game_id"]:
                prompt_events += f"{key}: {val}\n"
        prompt_events += "\n"
    system_prompt = generate_system_prompt()
    messages = [
        {
            "role": "system",
            "content": system_prompt,
        },
        {
            "role": "user",
            "content": prompt_events,
        },
    ]
    model = "gpt-3.5-turbo"
    openai.api_key = os.environ.get('OPENAI_KEY')
    logger.info("creating openai response")
    """"
    response = openai.ChatCompletion.create(
        model=model,
        messages=messages,
        temperature=.5
    )

    print("openai response", response)
    response_dict = response.to_dict_recursive()
    """
    response_dict = {
        "id": "chatcmpl-7YMy9JFXsIS9ARv17yKCbs28Jdp8x",
        "object": "chat.completion",
        "created": 1688425801,
        "model": "gpt-3.5-turbo-0613",
        "choices": [
            {
            "index": 0,
            "message": {
                "role": "assistant",
                "content": "[0:00] Kevin Harlan: And we're underway here in Miami as the Heat take on the Nuggets.\n[0:04] Reggie Miller: That's right, Kevin. It's going to be a great matchup tonight.\n\n[0:08] Kevin Harlan: Jump ball between Adebayo and Jokic, and Love comes away with the tip.\n[0:12] Reggie Miller: Love showing his hustle early in this game.\n\n[0:16] Kevin Harlan: Adebayo with a driving reverse layup, but it's no good.\n[0:20] Reggie Miller: Tough miss there by Adebayo, but he's not afraid to attack the rim.\n\n[0:24] Kevin Harlan: Jokic grabs the rebound off the miss.\n[0:28] Reggie Miller: Jokic, known for his rebounding ability, gets the job done there.\n\n[0:32] Kevin Harlan: Love commits a foul on Gordon.\n[0:36] Reggie Miller: That's Love's first foul of the game.\n\n[0:40] Kevin Harlan: Porter Jr. with a missed jump shot.\n[0:44] Reggie Miller: Porter Jr. couldn't find the mark on that one.\n\n[0:48] Kevin Harlan: Adebayo grabs the rebound.\n[0:52] Reggie Miller: Adebayo making his presence felt on the boards.\n\n[0:56] Kevin Harlan: Adebayo with a driving reverse layup, and he gets the basket!\n[1:00] Reggie Miller: Beautiful move by Adebayo to finish at the rim.\n\n[1:04] Kevin Harlan: Jokic misses a fadeaway jumper.\n[1:08] Reggie Miller: Jokic couldn't get that one to fall.\n\n[1:12] Kevin Harlan: Adebayo grabs another rebound.\n[1:16] Reggie Miller: Adebayo is dominating the boards right now.\n\n[1:20] Kevin Harlan: And that's the end of the first period.\n[1:24] Reggie Miller: The Heat have a 2-point lead heading into the second quarter."
            },
            "finish_reason": "stop"
            }
        ],
        "usage": {
            "prompt_tokens": 1381,
            "completion_tokens": 452,
            "total_tokens": 1833
        }
    }
    transcript_response = response_dict['choices'][0]['message']['content']
    transcript_array = transcript_response.split("\n")

    output_array = []
    for transcript_line in transcript_array:
        if transcript_line:
            output_array.append(transcript_line)

    transcript_output = []
    for raw_line in output_array:
        speaker_begin_time_stamp = re.findall(r'(?<=\[).+?(?=\])', raw_line)
        if not speaker_begin_time_stamp:
            print("timestamp not found. invalid line.")
            continue        
        speaker_name = "Kevin Harlan" if "Kevin Harlan" in raw_line else "Reggie Miller"
        beginning_index = raw_line.find(speaker_name)
        speaker_length = len(speaker_name)
        speech_content_beginning = beginning_index + speaker_length + 1
        extracted_speech_line = raw_line[speech_content_beginning:].strip()
        line_dict = {
            "speaker_begin_time": speaker_begin_time_stamp[0],
            "speaker_name": speaker_name,
            "line": extracted_speech_line
        }
        transcript_output.append(line_dict)   
    transcript_results_array = []
    for item, line_no in zip(transcript_output, range(1, len(transcript_output)+1)):
        cur_line = (
            transaction_id, line_no, item['speaker_name'], 
            item['speaker_begin_time'], item['line']
        )
        transcript_results_array.append(cur_line)
    #all_results = ", ".join(transcript_results_array)
    insert_query = """
        INSERT INTO transcript_results (transaction_id, line_number, speaker_name, time_spoken, spoken_line)
        VALUES %s;
    """
    cursor = connection.cursor()
    psycopg2.extras.execute_values(
        cursor, insert_query, transcript_results_array, 
        template=None, page_size=100
    )
    cursor.close()
    connection.commit()
    body = {
        "data": transcript_output
    }           
    response = {
        "body": json.dumps(body)
    }
    return response
