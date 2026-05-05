import boto3
import structlog

from app.services.providers.email.base import EmailProvider

_log = structlog.get_logger("provider.email.ses")


class SesEmailProvider(EmailProvider):
    def __init__(self, *, region: str, from_address: str) -> None:
        self._client = boto3.client("ses", region_name=region)
        self._from_address = from_address

    async def send(self, *, to: str, subject: str, body: str) -> None:
        _log.info("email.send", to=to, subject=subject)
        self._client.send_email(
            Source=self._from_address,
            Destination={"ToAddresses": [to]},
            Message={
                "Subject": {"Data": subject},
                "Body": {"Text": {"Data": body}},
            },
        )
