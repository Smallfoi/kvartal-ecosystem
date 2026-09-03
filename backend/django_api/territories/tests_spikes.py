# -*- coding: utf-8 -*-
"""GPS-иглы не становятся территорией («Идеальный маршрут», 03.09.2026).

Материализация контура (_CAP_SQL) режет выбросы двумя рубежами: морфологическое
закрытие ±CLOSE_EPS_M схлопывает тонкие треугольники-«бабочки», фильтр осколков
выбрасывает куски мельче SLIVER_MIN_M2. Здесь — регрессии на оба рубежа.
"""
import json

from common.testutils import ApiTestCase

# Квадрат ~110×110 м (~12 000 м²) у Якутска.
_SQUARE = [
    [62.000, 129.700],
    [62.001, 129.700],
    [62.001, 129.702],
    [62.000, 129.702],
]

# Такой же квадрат в СОСЕДНЕМ квартале (+0.01° lng, чтобы не упереться в
# 24-часовую защиту чужого захвата из первого теста) + GPS-игла: с восточной
# грани маршрут «телепортом» уходит на ~200 м и возвращается почти в ту же
# точку — узкий полуостров шириной ~2 м.
_SQUARE_WITH_SPIKE = [
    [62.000, 129.710],
    [62.001, 129.710],
    [62.001, 129.712],
    [62.0006, 129.712],
    [62.0006, 129.716],   # выброс: ~210 м на восток
    [62.00058, 129.712],  # вернулись — игла шириной ~2 м
    [62.000, 129.712],
]


class SpikeTrimTests(ApiTestCase):
    phone = "+79990002031"

    def _area(self, points, cid):
        r = self.api_post(
            "/v1/territories/capture", {"points": points, "captureId": cid}
        )
        self.assertEqual(r.status_code, 200, r.content)
        return r.json()["areaM2"]

    def test_spike_does_not_grow_territory(self):
        clean = self._area(_SQUARE, "capClean")
        # Отдельный юзер — чистая карта для варианта с иглой.
        tok = self.new_user("+79990002032")
        r = self.client.post(
            "/v1/territories/capture",
            data=json.dumps(
                {"points": _SQUARE_WITH_SPIKE, "captureId": "capSpike"}
            ),
            content_type="application/json",
            HTTP_AUTHORIZATION=f"Bearer {tok}",
        )
        self.assertEqual(r.status_code, 200, r.content)
        spiked = r.json()["areaM2"]
        # Игла ~200×2 м могла бы добавить ~400 м² и хвост на карте; после
        # закрытия площадь остаётся площадью квадрата (допуск на буфер ±5 м).
        self.assertLess(abs(spiked - clean) / clean, 0.12)

    def test_pure_jitter_rejected_as_too_small(self):
        # Псевдопетля из дрожи: пятачок ~6×6 м — тела зоны нет.
        jitter = [
            [62.0000, 129.7000],
            [62.00005, 129.70005],
            [62.00003, 129.70012],
            [62.00007, 129.70003],
        ]
        r = self.api_post(
            "/v1/territories/capture", {"points": jitter, "captureId": "capJit"}
        )
        self.assertEqual(r.status_code, 400)
        self.assertIn("маленькая", r.json()["detail"])
