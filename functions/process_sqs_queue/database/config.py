import os


class DatabaseConfig(object):
    def __init__(self, env_setting):
        if env_setting == 'dev':
            self.POSTGRES_USER = os.environ.get('POSTGRES_DEV_USER')
            self.POSTGRES_PW = os.environ.get('POSTGRES_DEV_PW')
            self.POSTGRES_URL = os.environ.get('POSTGRES_DEV_URL')
            self.POSTGRES_DB = os.environ.get('POSTGRES_DEV_DB')
            self.POSTGRES_PORT = os.environ.get('POSTGRES_DEV_PORT')         
        elif env_setting == 'test':
            self.POSTGRES_USER = os.environ.get('POSTGRES_TEST_USER')
            self.POSTGRES_PW = os.environ.get('POSTGRES_TEST_PW')
            self.POSTGRES_URL = os.environ.get('POSTGRES_TEST_URL')
            self.POSTGRES_DB = os.environ.get('POSTGRES_TEST_DB')
            self.POSTGRES_PORT = os.environ.get('POSTGRES_TEST_PORT')
        elif env_setting == 'prod':
            self.POSTGRES_USER = os.environ.get('POSTGRES_PROD_USERNAME')
            self.POSTGRES_PW = os.environ.get('POSTGRES_PROD_PASSWORD')
            self.POSTGRES_URL = os.environ.get('POSTGRES_PROD_HOST')
            self.POSTGRES_DB = os.environ.get('POSTGRES_PROD_DB')
            self.POSTGRES_PORT = os.environ.get('POSTGRES_PROD_PORT')
        self.db_url = self.create_db_url(
            self.POSTGRES_USER, self.POSTGRES_PW, 
            self.POSTGRES_URL, self.POSTGRES_DB
        )

    def create_db_url(self, user: str, pw: str, url: str, db:str) -> str:
        """
        Create URL to connect to PostgreSQL, with psycopg2 as the driver.
        'user' and 'pw' are the user's database credentials.
        'url' is the name of the host and the port number. e.g. 127.0.0.1:5432
        'db' is the name of the database.
        """
        return f"postgresql+psycopg2://{user}:{pw}@{url}/{db}"