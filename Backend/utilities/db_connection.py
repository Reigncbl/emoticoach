import asyncpg
import asyncio
import os
from dotenv import load_dotenv
load_dotenv()

CONNECTION = os.getenv("CONNECTION")



async def main():
    conn = await asyncpg.connect(CONNECTION)
    query = 'select * from "public"."activitylog" LIMIT 10;'
    extensions = await conn.fetch(query)
    for extension in extensions:
        print(extension)
        print("Returned")
    await conn.close()

asyncio.run(main())