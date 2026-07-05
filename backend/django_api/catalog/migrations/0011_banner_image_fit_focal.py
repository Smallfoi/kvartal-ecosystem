from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("catalog", "0010_sitecontent"),
    ]

    operations = [
        migrations.AddField(
            model_name="banner",
            name="image_fit",
            field=models.CharField(default="cover", max_length=10, verbose_name="Подгон фото"),
        ),
        migrations.AddField(
            model_name="banner",
            name="image_focal",
            field=models.CharField(default="50% 50%", max_length=16, verbose_name="Фокус фото"),
        ),
    ]
