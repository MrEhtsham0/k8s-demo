from faker import Faker
from sqlalchemy import func, select

from src.db.session import Base, SessionLocal, engine
from src.models.user import User

fake = Faker()
SEED_USER_COUNT = 100


def _build_seed_users(count: int = SEED_USER_COUNT) -> list[User]:
    users: list[User] = []
    used_emails: set[str] = set()

    while len(users) < count:
        email = fake.unique.email()
        if email in used_emails:
            continue
        used_emails.add(email)
        users.append(
            User(
                name=fake.name()[:120],
                email=email[:255],
                password=fake.password(length=12),
            )
        )
    return users


async def init_db() -> None:
    """Create tables and insert seed users if the table is empty."""
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    async with SessionLocal() as session:
        result = await session.execute(select(func.count()).select_from(User))
        if result.scalar_one() > 0:
            return

        session.add_all(_build_seed_users())
        await session.commit()
