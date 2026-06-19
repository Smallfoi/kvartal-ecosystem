from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('shoes', '0002_shoeasset_applied_runs'),
    ]

    operations = [
        migrations.AddField(
            model_name='shoeasset',
            name='status',
            field=models.CharField(db_index=True, default='pending', max_length=12),
        ),
    ]
