from __future__ import annotations


class SkanQRCodeError(Exception):
    def __init__(self, code: str, message: str, request_id: str | None, status_code: int) -> None:
        super().__init__(message)
        self.code = code
        self.message = message
        self.request_id = request_id
        self.status_code = status_code
