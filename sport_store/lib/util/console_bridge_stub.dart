// Заглушка для мобильных сборок (не web): конструктор недоступен.
void postReorder(List<String> productIds) {}
void postEditContent(String key, String value,
    {String color = '', bool hasColor = false}) {}
void postEditImage(String key, String url,
    {String focal = '', String fit = 'cover', double aspect = 0}) {}
void postEditBg(String key,
    {String img = '', String vid = '', String off = '', String focal = '', String fit = 'cover'}) {}
void postReady() {}
void onConsoleSetContent(void Function(String key, String value) cb) {}
void onConsoleSetImage(void Function(String key, String url) cb) {}
