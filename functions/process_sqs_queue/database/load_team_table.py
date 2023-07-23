from models.team import Team
from pathlib import Path
from sqlalchemy.orm import Session
from database.config import DatabaseConfig
import csv
from sqlalchemy import create_engine
import logging
from models.base import Base

logger = logging.getLogger(__name__)
f_handler = logging.FileHandler('load_team_table.log')

class TeamTableLoader:
    def __init__(self, csv_directory):
        self.model = Team
        self.data_directory = Path(csv_directory)
        self.db_config = DatabaseConfig("production")
    
    def load_db(self):
        csv_files = [file for file in self.data_directory.rglob("*.csv")]
        engine = create_engine(self.db_config.db_url)
        Base.metadata.create_all(engine)
        with Session(engine) as session:
            for raw_file in csv_files:
                with open(raw_file, newline='') as csvfile:
                    reader = csv.DictReader(csvfile)
                    for row in reader:
                        clean_row = {}
                        clean_row['team_id'] = row['id']
                        clean_row['abbreviation'] = row['abbreviation']
                        clean_row['full_name'] = row['full_name']
                        clean_row['nickname'] = row['nickname']
                        clean_row['city'] = row['city']
                        clean_row['state'] = row['state']
                        clean_row['year_founded'] = row['year_founded']
                        current_rec = Team(clean_row)
                        logger.info("Adding row to session")
                        session.add(current_rec)
                        logger.info("Added row to session")
                session.commit()