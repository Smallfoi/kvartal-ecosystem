import django.utils.timezone
from django.db import migrations, models


class Migration(migrations.Migration):

    initial = True

    dependencies = [
    ]

    operations = [
        migrations.CreateModel(
            name='ShoeAsset',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('user_id', models.CharField(db_index=True, max_length=40)),
                ('product_id', models.CharField(max_length=40)),
                ('order_id', models.CharField(blank=True, default='', max_length=40)),
                ('model', models.CharField(blank=True, default='', max_length=200)),
                ('image_url', models.CharField(blank=True, default='', max_length=400)),
                ('total_km', models.FloatField(default=0)),
                ('max_km', models.FloatField(default=600)),
                ('retired', models.BooleanField(default=False)),
                ('created_at', models.DateTimeField(default=django.utils.timezone.now)),
            ],
            options={
                'db_table': 'store_shoes',
                'ordering': ['-created_at'],
                'unique_together': {('user_id', 'order_id', 'product_id')},
            },
        ),
    ]
