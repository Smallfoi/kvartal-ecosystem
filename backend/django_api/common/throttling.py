"""Rate-limiting (P0 безопасность). Аутентификация у нас своя (JWT в common.security),
поэтому стандартный UserRateThrottle по request.user не работает — ключуемся по `sub`
из токена. Неаутентифицированные — по IP. Вход/регистрация — отдельный жёсткий лимит
(анти-брутфорс кода/пароля).

Прод: общий кэш (Redis) для счётчиков на нескольких воркерах — см. план D-07."""
from rest_framework.throttling import SimpleRateThrottle

from common.security import user_id_from_request


class UserJWTRateThrottle(SimpleRateThrottle):
    """Лимит на пользователя (по JWT sub). Анонимные — пропускаем (их ловит AnonIP)."""
    scope = "user"

    def get_cache_key(self, request, view):
        uid = user_id_from_request(request)
        if not uid:
            return None
        return self.cache_format % {"scope": self.scope, "ident": uid}


class AnonIPRateThrottle(SimpleRateThrottle):
    """Лимит по IP для НЕаутентифицированных (каталог Store, вход). С токеном — пропускаем
    (чтобы не штрафовать многих пользователей за одним NAT/прокси оператора)."""
    scope = "anon"

    def get_cache_key(self, request, view):
        if user_id_from_request(request):
            return None
        return self.cache_format % {"scope": self.scope, "ident": self.get_ident(request)}


class AuthEndpointThrottle(SimpleRateThrottle):
    """Жёсткий лимит по IP на /auth (вход/регистрация) — анти-брутфорс."""
    scope = "auth"

    def get_cache_key(self, request, view):
        return self.cache_format % {"scope": self.scope, "ident": self.get_ident(request)}
