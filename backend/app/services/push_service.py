"""Push framework (2.3 — item 11d first half).

Device registration + fan-out to a user's devices via the PushProvider
(logs in dev, APNS/FCM in Tier 3.3). Push is strictly fire-and-forget:
`notify_user` never raises — a push must never fail the request that
triggered it. The 18 campaign notifications land with the scheduler in
Tier 3.3; transactional triggers call `notify_user` directly.
"""
from __future__ import annotations

from uuid import UUID

import structlog
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db.models import Device, User
from app.services.providers.push.base import PushProvider

_log = structlog.get_logger("push")


def register_device(
    db: Session, *, user: User, platform: str, token: str
) -> Device:
    """Upsert by token: devices get wiped/re-logged-in, and a token must only
    ever target its current owner."""
    row = db.scalar(select(Device).where(Device.token == token))
    if row is None:
        row = Device(user_id=user.id, platform=platform, token=token)
        db.add(row)
    else:
        row.user_id = user.id
        row.platform = platform
    db.commit()
    db.refresh(row)
    _log.info(
        "push.device.registered",
        user_id=str(user.id),
        platform=platform,
        device_id=str(row.id),
    )
    return row


def remove_device(db: Session, *, user: User, token: str) -> bool:
    row = db.scalar(
        select(Device).where(Device.token == token, Device.user_id == user.id)
    )
    if row is None:
        return False
    db.delete(row)
    db.commit()
    return True


def notify_user(
    db: Session,
    *,
    push: PushProvider | None,
    user_id: UUID,
    title: str,
    body: str,
    data: dict[str, str] | None = None,
) -> int:
    """Best-effort fan-out to every registered device. Returns how many sends
    were attempted; never raises."""
    if push is None:
        # Feature-disabled (DISABLED_FEATURES=push): a logged no-op, not an
        # error — pushes are server-initiated, there is no caller to 400.
        _log.info("push.disabled_skip", user_id=str(user_id))
        return 0
    devices = list(db.scalars(select(Device).where(Device.user_id == user_id)).all())
    sent = 0
    for d in devices:
        try:
            push.send(
                device_token=d.token,
                platform=d.platform,
                title=title,
                body=body,
                data=data,
            )
            sent += 1
        except Exception:  # noqa: BLE001 — push must never break a request
            _log.exception("push.send_failed", device_id=str(d.id))
    return sent
