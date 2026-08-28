#!/usr/bin/env bash
# Восстановление прод-ВМ mata-prod ПОСЛЕ неудачного пересоздания:
# старая ВМ уже удалена, а `yc-recreate.sh` упал на create (была опечатка
# mode=read-write вместо mode=rw). Этот скрипт НЕ читает параметры из отсутствующей
# ВМ — все id заданы литералами (это НЕ секреты: подсеть/группа/диск/образ + reserved IP).
# Диск с БД (autoDelete=false) и статический IP (reserved) сохранились и переподключаются.
#
# Запуск в Yandex Cloud Shell:
#   cd /tmp/mata-ecosystem && git pull && bash backend/deploy/yc-restore-prod.sh
set -euo pipefail

NAME=mata-prod
CI_URL="https://raw.githubusercontent.com/Smallfoi/mata-ecosystem/main/backend/deploy/cloud-init-prod.yaml"

# Защита от повторного запуска: если ВМ уже создана — ничего не делаем.
if yc compute instance get --name "$NAME" >/dev/null 2>&1; then
  echo "ВМ $NAME уже существует — ничего не делаю (проверь статус в консоли)."
  exit 0
fi

echo "== 1/2 Скачиваю cloud-init (с исправленным SSH) =="
curl -fsSL "$CI_URL" -o /tmp/mata-ci.yaml
echo "   строк: $(wc -l < /tmp/mata-ci.yaml)"

echo "== 2/2 Создаю ВМ $NAME (диск БД + статический IP + fixed SSH) =="
yc compute instance create \
  --name "$NAME" \
  --zone ru-central1-b \
  --platform standard-v3 \
  --cores 2 \
  --memory 4G \
  --core-fraction 100 \
  --create-boot-disk image-id=fd8u2mfll3sb60ohsg7t,size=30G,type=network-ssd \
  --attach-disk disk-id=epd94mrarshi07fqk76r,auto-delete=false,mode=rw \
  --network-interface subnet-id=e2lrgpcelk00ugbo1f0n,security-group-ids=enptivfkcai2uguhb837,nat-address=158.160.12.117 \
  --metadata-from-file user-data=/tmp/mata-ci.yaml \
  --metadata "enable-oslogin=false"

echo ""
echo "=================================================="
echo "  Готово. IP: 158.160.12.117 (тот же — DNS не трогаем)."
echo "  Сервер сам развернёт стек за ~5-7 мин, HTTPS переиздастся."
echo "=================================================="
