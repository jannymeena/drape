import structlog

from app.services.providers.email.base import EmailProvider

_log = structlog.get_logger("provider.email.log")


class LogEmailProvider(EmailProvider):
    async def send(self, *, to: str, subject: str, body: str) -> None:
        _log.info("email.send (dev — not actually sending)", to=to, subject=subject, body=body)
