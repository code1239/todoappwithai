"""Alan bazli sifreleme yardimcilari (Fernet).

DB'de saklanan duyarli alanlar bu modul uzerinden sifrelenir. Sifreli
degerler 'enc:' on ekiyle baslar; ozellikle eski duz metin satirlarla
geriye uyumluluk icin dec() sifreli olmayan degeri oldugu gibi dondurur.
"""

import json
import os

from cryptography.fernet import Fernet, InvalidToken

PREFIX = 'enc:'


def _fernet() -> Fernet:
    return Fernet(os.getenv('ENC_KEY', '').encode())


def is_encrypted(value) -> bool:
    return bool(value) and isinstance(value, str) and value.startswith(PREFIX)


def enc(value) -> str:
    """Duz metni sifreler. Bos deger sifrelenmez."""
    if value is None:
        return ''
    s = str(value)
    if not s or is_encrypted(s):
        return s
    return PREFIX + _fernet().encrypt(s.encode('utf-8')).decode('utf-8')


def dec(value) -> str:
    """Sifreli degeri cozer; sifreli degilse oldugu gibi dondurur."""
    if not value or not is_encrypted(value):
        return '' if value is None else str(value)
    try:
        return _fernet().decrypt(value[len(PREFIX):].encode('utf-8')).decode('utf-8')
    except (InvalidToken, ValueError):
        return str(value)


def enc_json(obj) -> str:
    """JSON objesini serilestirip sifreler (bos sutun icin '')."""
    if obj in (None, {}, []):
        return ''
    if isinstance(obj, str) and is_encrypted(obj):
        return obj
    return enc(json.dumps(obj, ensure_ascii=False))


def dec_json(value):
    """Sifreli JSON stringini cozer ve parse eder. Bos/gecersizse {} dondurur."""
    if not value:
        return {}
    decrypted = dec(value)
    try:
        return json.loads(decrypted)
    except (json.JSONDecodeError, TypeError):
        return {}