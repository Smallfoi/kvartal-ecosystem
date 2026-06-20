import django.utils.timezone
from django.db import migrations, models


class Migration(migrations.Migration):

    initial = True

    dependencies = [
    ]

    operations = [
        migrations.CreateModel(
            name='Notification',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('user_id', models.CharField(db_index=True, max_length=40)),
                ('title', models.CharField(max_length=200)),
                ('body', models.CharField(blank=True, default='', max_length=500)),
                ('type', models.CharField(default='system', max_length=20)),
                ('order_id', models.CharField(blank=True, max_length=40, null=True)),
                ('read', models.BooleanField(default=False)),
                ('created_at', models.DateTimeField(default=django.utils.timezone.now)),
            ],
            options={
                'db_table': 'notifications',
                'ordering': ['-created_at'],
            },
        ),
    ]
