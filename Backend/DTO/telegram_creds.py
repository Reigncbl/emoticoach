import sqlmodel

class TelegramCreds(sqlmodel.SQLModel, table=True):
  
    id: int = sqlmodel.Field(default=None, primary_key=True)
    bot_token: str
    chat_id: int
    is_active: bool = sqlmodel.Field(default=True)