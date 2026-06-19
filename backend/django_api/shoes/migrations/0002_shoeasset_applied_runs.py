from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('shoes', '0001_initial'),
    ]

    operations = [
        migrations.AddField(
            model_name='shoeasset',
            name='applied_runs',
            field=models.JSONField(default=list),
        ),
    ]
