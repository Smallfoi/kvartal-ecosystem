#!/usr/bin/env bash
# Пересоздание прод-ВМ mata-prod в Yandex Cloud с ГАРАНТИРОВАННЫМ SSH-доступом
# (публичный ключ + enable-oslogin=false с первой загрузки) и авто-выпуском TLS.
#
# Запускать в Yandex Cloud Shell (там `yc` уже авторизован владельцем):
#   curl -fsSL https://raw.githubusercontent.com/Smallfoi/mata-ecosystem/main/backend/deploy/yc-recreate.sh | bash
#
# После завершения скрипт напечатает НОВЫЙ IP — обнови на него A-запись
# api.mata-club.ru, и сервер сам развернётся и выпустит HTTPS за ~7 минут.
set -euo pipefail

NAME=mata-prod
CI_URL="https://raw.githubusercontent.com/Smallfoi/mata-ecosystem/main/backend/deploy/cloud-init-prod.yaml"
PY=python3

echo "== 1/5 Читаю сеть текущей ВМ ($NAME) =="
J="$(yc compute instance get --name "$NAME" --format json)"
SUBNET="$(printf '%s' "$J" | "$PY" -c "import sys,json;print(json.load(sys.stdin)['network_interfaces'][0]['subnet_id'])")"
SG="$(printf '%s' "$J" | "$PY" -c "import sys,json;d=json.load(sys.stdin)['network_interfaces'][0];print((d.get('security_group_ids') or [''])[0])")"
DISK="$(printf '%s' "$J" | "$PY" -c "import sys,json;print(json.load(sys.stdin)['boot_disk']['disk_id'])")"
IMAGE="$(yc compute disk get --id "$DISK" --format json | "$PY" -c "import sys,json;print(json.load(sys.stdin).get('source_image_id',''))")"
echo "   subnet=$SUBNET sg=$SG image=$IMAGE"
[ -n "$IMAGE" ] || { echo "Не удалось определить образ — прерываю."; exit 1; }

echo "== 2/5 Скачиваю cloud-init =="
curl -fsSL "$CI_URL" -o /tmp/mata-ci.yaml
echo "   строк: $(wc -l < /tmp/mata-ci.yaml)"

echo "== 3/5 Удаляю старую ВМ =="
yc compute instance delete --name "$NAME"

echo "== 4/5 Создаю новую ВМ (ключ + enable-oslogin=false) =="
NIC="subnet-id=$SUBNET,nat-ip-version=ipv4"
[ -n "$SG" ] && NIC="subnet-id=$SUBNET,security-group-ids=$SG,nat-ip-version=ipv4"
yc compute instance create \
  --name "$NAME" \
  --zone ru-central1-b \
  --platform standard-v3 \
  --cores 2 \
  --memory 4G \
  --core-fraction 100 \
  --create-boot-disk "image-id=$IMAGE,size=30G,type=network-ssd" \
  --network-interface "$NIC" \
  --metadata-from-file "user-data=/tmp/mata-ci.yaml" \
  --metadata "enable-oslogin=false"

echo "== 5/5 Готово. Определяю новый IP =="
NEWIP="$(yc compute instance get --name "$NAME" --format json | "$PY" -c "import sys,json;print(json.load(sys.stdin)['network_interfaces'][0]['primary_v4_address']['one_to_one_nat']['address'])")"
echo ""
echo "=================================================="
echo "  НОВЫЙ IP:  $NEWIP"
echo ""
echo "  Обнови DNS:  api.mata-club.ru  ->  $NEWIP"
echo ""
echo "  Через ~7 минут сервер сам поднимет стек и, как"
echo "  только DNS укажет на новый IP, выпустит HTTPS."
echo "=================================================="
