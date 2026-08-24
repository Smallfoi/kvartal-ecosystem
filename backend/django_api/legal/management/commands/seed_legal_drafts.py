"""Создаёт ЧЕРНОВИКИ юридических документов экосистемы (LegalDocument, НЕ опубликованные).

Полные тексты-черновики — в `docs/legal/*.md`. Порядок ввода в работу:
  1. Юрист проверяет/правит docs/legal/*.md, заполняются реквизиты оператора.
  2. python manage.py seed_legal_drafts   # создаёт записи-черновики (если ещё нет)
  3. В админке /admin/ → «Документы»: вставить утверждённый текст в поле «Текст» и ОПУБЛИКОВАТЬ.
После публикации приложения и сайт тянут актуальную версию по GET /v1/legal/documents (централизованно).
"""
from django.core.management.base import BaseCommand

from legal.models import LegalDocument

# (doc_type, заголовок, обязателен ли к принятию, файл-исходник в docs/legal/)
DRAFTS = [
    ("terms", "Пользовательское соглашение", True, "01-terms.md"),
    ("privacy", "Политика конфиденциальности", True, "02-privacy.md"),
    ("pd_consent", "Согласие на обработку персональных данных", True, "03-pd-consent.md"),
    ("marketing", "Согласие на рекламные рассылки", False, "04-marketing-consent.md"),
    ("offer", "Публичная оферта (Store)", True, "05-offer.md"),
    ("loyalty", "Правила программы лояльности", True, "06-loyalty-rules.md"),
    ("club", "Правила сообщества и клубов", True, "07-community-rules.md"),
    # Не требуют принятия галочкой, но обязаны быть опубликованы на витрине:
    # без них платёжный сервис не включит приём платежей.
    ("delivery", "Доставка и получение заказа", False, "09-delivery.md"),
    ("returns", "Возврат и обмен", False, "10-returns.md"),
]
_VERSION = "1.0-draft"


class Command(BaseCommand):
    help = "Создаёт черновики юр-документов (LegalDocument, не опубликованные). Текст — из docs/legal/."

    def handle(self, *args, **options):
        created = 0
        for doc_type, title, required, fname in DRAFTS:
            _, is_new = LegalDocument.objects.get_or_create(
                doc_type=doc_type,
                version=_VERSION,
                defaults={
                    "title": title,
                    "is_required": required,
                    "published_at": None,  # ЧЕРНОВИК — публикует человек в админке
                    "body": (
                        f"ЧЕРНОВИК. Полный текст — docs/legal/{fname}.\n\n"
                        "Порядок: (1) юрист проверяет и правит текст, заполняются реквизиты "
                        "оператора; (2) утверждённый текст вставляется в это поле; "
                        "(3) документ публикуется. После публикации приложения и сайт "
                        "показывают его автоматически (GET /v1/legal/documents)."
                    ),
                },
            )
            if is_new:
                created += 1
        total = LegalDocument.objects.filter(version=_VERSION).count()
        self.stdout.write(self.style.SUCCESS(
            f"Черновики юр-документов: создано {created}, всего ({_VERSION}) {total}. "
            "НЕ опубликованы — опубликовать в админке после проверки юристом."
        ))
