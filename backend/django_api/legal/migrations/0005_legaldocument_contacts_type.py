from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('legal', '0004_legaldocument_distribution_type'),
    ]

    operations = [
        migrations.AlterField(
            model_name='legaldocument',
            name='doc_type',
            field=models.CharField(choices=[('terms', 'Пользовательское соглашение'), ('privacy', 'Политика конфиденциальности'), ('pd_consent', 'Согласие на обработку ПД'), ('marketing', 'Рекламные коммуникации'), ('offer', 'Оферта (Store)'), ('loyalty', 'Правила лояльности'), ('club', 'Правила сообщества'), ('delivery', 'Доставка и получение'), ('returns', 'Возврат и обмен'), ('distribution', 'Распространение ПДн (ст. 10.1)'), ('competition', 'Правила соревнований'), ('contacts', 'Контакты')], db_index=True, max_length=20, verbose_name='Тип документа'),
        ),
    ]
