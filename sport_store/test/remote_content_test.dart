import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sport_store/providers/remote_content_provider.dart';
import 'package:sport_store/widgets/remote_text.dart';

void main() {
  group('RemoteContentProvider', () {
    test('text() возвращает фолбэк, когда контента нет', () {
      final p = RemoteContentProvider(null); // api null → без загрузки
      expect(p.text('app.home.title', 'SPORT STORE'), 'SPORT STORE');
      expect(p.text('app.cat.tshirts', 'Футболки'), 'Футболки');
    });

    test('applyDraft задаёт значение; пустое — снимает (→ фолбэк)', () {
      final p = RemoteContentProvider(null);
      p.applyDraft('app.home.catTitle', 'РАЗДЕЛЫ');
      expect(p.text('app.home.catTitle', 'КАТЕГОРИИ'), 'РАЗДЕЛЫ');
      p.applyDraft('app.home.catTitle', ''); // пусто = вернуть фолбэк
      expect(p.text('app.home.catTitle', 'КАТЕГОРИИ'), 'КАТЕГОРИИ');
    });

    test('applyDraft уведомляет слушателей', () {
      final p = RemoteContentProvider(null);
      var notified = 0;
      p.addListener(() => notified++);
      p.applyDraft('app.x', 'значение');
      expect(notified, 1);
    });

    test('color/focal/fit читаются из служебных ключей', () {
      final p = RemoteContentProvider(null);
      expect(p.color('app.home.title'), ''); // по умолчанию нет
      p.applyDraft('color.app.home.title', '#ffffff');
      p.applyDraft('focal.app.cat.shoes.img', '20% 80%');
      p.applyDraft('fit.app.cat.shoes.img', 'contain');
      expect(p.color('app.home.title'), '#ffffff');
      expect(p.focal('app.cat.shoes.img'), '20% 80%');
      expect(p.fit('app.cat.shoes.img'), 'contain');
    });

    test('value() читает служебные bg-поля; фон = imageUrl(bg.<k>)', () {
      final p = RemoteContentProvider(null);
      expect(p.value('bgvid.app.onb.bg'), '');
      p.applyDraft('bgoff.app.onb.bg', '1');
      p.applyDraft('bgvid.app.onb.bg', 'https://x/clip.mp4');
      p.applyDraft('bgfocal.app.onb.bg', '30% 70%');
      expect(p.value('bgoff.app.onb.bg'), '1');
      expect(p.value('bgvid.app.onb.bg'), 'https://x/clip.mp4');
      expect(p.value('bgfocal.app.onb.bg'), '30% 70%');
      // фото фона идёт через imageUrl(bg.<k>)
      p.applyImageDraft('bg.app.onb.bg', 'data:image/png;base64,AAAA');
      expect(p.imageUrl('bg.app.onb.bg'), 'data:image/png;base64,AAAA');
    });

    test('applyImageDraft задаёт/снимает URL фото и уведомляет', () {
      final p = RemoteContentProvider(null);
      var notified = 0;
      p.addListener(() => notified++);
      expect(p.imageUrl('app.cat.shoes.img'), '');
      p.applyImageDraft('app.cat.shoes.img', 'data:image/png;base64,AAAA');
      expect(p.imageUrl('app.cat.shoes.img'), 'data:image/png;base64,AAAA'); // dataURL как есть
      p.applyImageDraft('app.cat.shoes.img', ''); // пусто = снять → фолбэк
      expect(p.imageUrl('app.cat.shoes.img'), '');
      expect(notified, 2);
    });
  });

  group('RemoteText.parseHex', () {
    test('#rrggbb → непрозрачный Color', () {
      expect(RemoteText.parseHex('#ffffff'), const Color(0xFFFFFFFF));
      expect(RemoteText.parseHex('#111111'), const Color(0xFF111111));
    });
    test('#rgb расширяется', () {
      expect(RemoteText.parseHex('#fff'), const Color(0xFFFFFFFF));
    });
    test('пустое/битое → null', () {
      expect(RemoteText.parseHex(''), isNull);
      expect(RemoteText.parseHex('красный'), isNull);
    });
  });
}
