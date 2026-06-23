from django.db import models
from django.utils import timezone


class Club(models.Model):
    id = models.CharField(primary_key=True, max_length=40)
    name = models.CharField(max_length=200)
    logo = models.CharField(max_length=200, null=True, blank=True)
    city = models.CharField(max_length=120, null=True, blank=True)
    description = models.TextField(null=True, blank=True)
    owner_id = models.CharField(max_length=40)
    join_policy = models.CharField(max_length=20, default="open")  # 'open' | 'request'
    created_at = models.DateTimeField(default=timezone.now)
    # Модерация (S-10): скрытый клуб не виден в списке и в него нельзя вступить.
    is_hidden = models.BooleanField(default=False, db_index=True)

    class Meta:
        db_table = "clubs"


class ClubMember(models.Model):
    club_id = models.CharField(max_length=40, db_index=True)
    # уникальность user_id = один клуб на человека (как в FastAPI на уровне БД)
    user_id = models.CharField(max_length=40, unique=True)
    role = models.CharField(max_length=20, default="member")  # 'owner' | 'member'
    joined_at = models.DateTimeField(default=timezone.now)

    class Meta:
        db_table = "club_members"
        unique_together = (("club_id", "user_id"),)


class ClubJoinRequest(models.Model):
    id = models.CharField(primary_key=True, max_length=40)
    club_id = models.CharField(max_length=40, db_index=True)
    user_id = models.CharField(max_length=40)
    status = models.CharField(max_length=20, default="pending")  # pending|approved|rejected
    created_at = models.DateTimeField(default=timezone.now)

    class Meta:
        db_table = "club_join_requests"
