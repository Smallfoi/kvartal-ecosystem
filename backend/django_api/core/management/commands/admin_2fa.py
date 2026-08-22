"""Подключение двухфакторного входа администратору (D-49).

    python manage.py admin_2fa <логин>            # подключить
    python manage.py admin_2fa <логин> --reset    # выдать новое устройство и коды
    python manage.py admin_2fa <логин> --off      # отключить (снять защиту)

Печатает QR-код прямо в терминал: наводишь камерой из приложения-аутентификатора
(Яндекс Ключ, Google Authenticator, 1Password, любое другое) — и всё.
Плюс десять запасных кодов на случай потери телефона: каждый срабатывает один
раз, храни их отдельно от телефона.
"""
from django.contrib.auth import get_user_model
from django.core.management.base import BaseCommand, CommandError


class Command(BaseCommand):
    help = "Подключает/отключает двухфакторный вход администратору."

    def add_arguments(self, parser):
        parser.add_argument("username", help="логин администратора")
        parser.add_argument("--reset", action="store_true",
                            help="выдать новое устройство и новые запасные коды")
        parser.add_argument("--off", action="store_true",
                            help="отключить двухфакторный вход")

    def handle(self, *args, **o):
        from django_otp.plugins.otp_static.models import StaticDevice, StaticToken
        from django_otp.plugins.otp_totp.models import TOTPDevice

        User = get_user_model()
        try:
            user = User.objects.get(**{User.USERNAME_FIELD: o["username"]})
        except User.DoesNotExist:
            raise CommandError(f"Пользователь «{o['username']}» не найден.")
        if not user.is_staff:
            raise CommandError("Двухфакторный вход нужен только сотрудникам админки.")

        if o["off"]:
            n = TOTPDevice.objects.filter(user=user).delete()[0]
            n += StaticDevice.objects.filter(user=user).delete()[0]
            self.stdout.write(f"Двухфакторный вход отключён (удалено записей: {n}).")
            self.stdout.write("Вход теперь только по паролю — так делать не стоит.")
            return

        exists = TOTPDevice.objects.filter(user=user, confirmed=True).exists()
        if exists and not o["reset"]:
            self.stdout.write("Двухфакторный вход уже подключён.")
            self.stdout.write("Нужны новые коды или новый телефон — повтори с --reset.")
            return

        TOTPDevice.objects.filter(user=user).delete()
        StaticDevice.objects.filter(user=user).delete()

        device = TOTPDevice.objects.create(user=user, name="МАТА админка", confirmed=True)
        url = device.config_url

        self.stdout.write("")
        self.stdout.write("Наведи камеру приложения-аутентификатора на QR ниже:")
        self.stdout.write("")
        self._qr(url)
        self.stdout.write("")
        self.stdout.write("Если камера не читает — добавь вручную по ссылке:")
        self.stdout.write(f"  {url}")

        # Запасные коды: без них потерянный телефон означает потерянную админку.
        static = StaticDevice.objects.create(user=user, name="Запасные коды", confirmed=True)
        codes = [StaticToken.random_token() for _ in range(10)]
        for c in codes:
            StaticToken.objects.create(device=static, token=c)

        self.stdout.write("")
        self.stdout.write("Запасные коды (каждый срабатывает один раз):")
        for c in codes:
            self.stdout.write(f"  {c}")
        self.stdout.write("")
        self.stdout.write("Сохрани их ОТДЕЛЬНО от телефона — иначе потеряешь всё разом.")
        self.stdout.write("Повторно они не покажутся: новые — через --reset.")

    def _qr(self, url: str):
        """QR прямо в терминале. Без библиотеки просто пропускаем — ссылка выше есть."""
        try:
            import qrcode
        except ImportError:
            self.stdout.write("  (модуль qrcode не установлен — добавь вручную по ссылке)")
            return
        qr = qrcode.QRCode(border=1)
        qr.add_data(url)
        qr.make(fit=True)
        m = qr.get_matrix()
        # Две строки матрицы в один ряд символов: так QR не растягивается по высоте
        # и целиком помещается в окно терминала.
        for y in range(0, len(m), 2):
            row = ""
            for x in range(len(m[y])):
                top = m[y][x]
                bottom = m[y + 1][x] if y + 1 < len(m) else False
                row += {(True, True): "█", (True, False): "▀",
                        (False, True): "▄", (False, False): " "}[(top, bottom)]
            self.stdout.write(row)
