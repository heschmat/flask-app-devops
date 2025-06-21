import time

from sqlalchemy import text
from sqlalchemy.exc import OperationalError

from config import db, app


max_tries = 3

with app.app_context():
    for i in range(1, max_tries+1):
        try:
            db.session.execute(text("SELECT 1"))
            break
        except OperationalError:
            print(f"❌ DB not ready, retrying in {i ** 2} seconds...")
            time.sleep(i**2)
    else:
        raise Exception("DB not ready after retries")

    # After db is ready, start table creation ...
    db.session.execute(text(open("./db/1_create_tables.sql").read()))
    db.session.commit()
    print("✅ Tables created.")
    existing = db.session.execute(text("SELECT COUNT(*) FROM users")).scalar()
    if existing == 0:
        db.session.execute(text(open("./db/2_seed_users.sql").read()))
        db.session.commit()
        print("✅ Seed data inserted.")
    else:
        print("ℹ️ Users already exist. Skipping seed.")
