# -*- coding: utf-8 -*-
"""Сид каталога Store — 1:1 с прежним mock_data.dart SportStore.
Картинки — бандл-ассеты приложения (assets/images/...), бэк отдаёт только пути."""

CATEGORIES = [
    {"id": "all", "name": "Все", "emoji": "⚡"},
    {"id": "tshirts", "name": "Футболки", "emoji": "👕"},
    {"id": "hoodies", "name": "Худи", "emoji": "🧥"},
    {"id": "pants", "name": "Брюки", "emoji": "👖"},
    {"id": "jackets", "name": "Куртки", "emoji": "🧤"},
    {"id": "shoes", "name": "Кроссовки", "emoji": "👟"},
    {"id": "accessories", "name": "Аксессуары", "emoji": "🎒"},
]

PRODUCTS = [
    {
        "id": "1", "name": "Беговая футболка Pro Dry", "brand": "SportStore",
        "categoryId": "tshirts", "price": 2990, "oldPrice": 4500,
        "imageUrls": [
            "assets/images/products/1521572163474-6864f9cf17ab.jpg",
            "assets/images/products/1618354691373-d851c5c3a990.jpg",
            "assets/images/products/1571945153237-4929e783af4a.jpg",
        ],
        "description": "Лёгкая беговая футболка из влагоотводящего материала. Идеально подходит для интенсивных тренировок и бега на длинные дистанции. Технология Dry-Fit обеспечивает максимальный комфорт.",
        "sizes": ["XS", "S", "M", "L", "XL", "XXL"],
        "colors": ["Белый", "Чёрный", "Серый"],
        "isNew": True, "isFeatured": True, "rating": 4.8, "reviewCount": 124,
    },
    {
        "id": "2", "name": "Худи Essential Fleece", "brand": "UrbanFit",
        "categoryId": "hoodies", "price": 5990,
        "imageUrls": [
            "assets/images/products/1620799140408-edc6dcb6d633.jpg",
            "assets/images/products/1515886657613-9f3515b0c78f.jpg",
        ],
        "description": "Тёплое флисовое худи для повседневной носки и тренировок в холодную погоду. Кенгуру-карман, регулируемый капюшон. Мягкий внутренний флис согревает в любую погоду.",
        "sizes": ["S", "M", "L", "XL", "XXL"],
        "colors": ["Чёрный", "Серый меланж", "Тёмно-синий"],
        "isFeatured": True, "rating": 4.9, "reviewCount": 89,
    },
    {
        "id": "3", "name": "Кроссовки Air Runner X1", "brand": "RunTech",
        "categoryId": "shoes", "price": 12990, "oldPrice": 15990,
        "imageUrls": [
            "assets/images/products/1542291026-7eec264c27ff.jpg",
            "assets/images/products/1608231387042-66d1773070a5.jpg",
            "assets/images/products/1556906781-9a412961c28c.jpg",
        ],
        "description": "Профессиональные беговые кроссовки с амортизирующей подошвой. Сетчатый верх обеспечивает вентиляцию. Идеальны для бега по асфальту и дорожке.",
        "sizes": ["39", "40", "41", "42", "43", "44", "45"],
        "colors": ["Белый/Чёрный", "Чёрный/Серый", "Серый/Белый"],
        "isNew": True, "isFeatured": True, "rating": 4.7, "reviewCount": 203,
    },
    {
        "id": "4", "name": "Спортивные брюки Taper Fit", "brand": "SportStore",
        "categoryId": "pants", "price": 4490,
        "imageUrls": [
            "assets/images/products/1506629082955-511b1aa562c8.jpg",
            "assets/images/products/1552902865-b72c031ac5ea.jpg",
        ],
        "description": "Зауженные спортивные брюки с эластичным поясом. Боковые карманы на молнии. Подходят для тренировок и повседневной носки.",
        "sizes": ["XS", "S", "M", "L", "XL", "XXL"],
        "colors": ["Чёрный", "Тёмно-серый", "Антрацит"],
        "rating": 4.6, "reviewCount": 67,
    },
    {
        "id": "5", "name": "Ветровка Shield Pro", "brand": "ProGear",
        "categoryId": "jackets", "price": 8990, "oldPrice": 11990,
        "imageUrls": [
            "assets/images/products/1591047139829-d91aecb6caea.jpg",
            "assets/images/products/1551488831-00ddcb6c6bd3.jpg",
        ],
        "description": "Лёгкая ветрозащитная куртка с водоотталкивающим покрытием. Упаковывается в собственный карман. Светоотражающие элементы для безопасности.",
        "sizes": ["S", "M", "L", "XL", "XXL"],
        "colors": ["Чёрный", "Тёмно-синий", "Хаки"],
        "isNew": True, "rating": 4.8, "reviewCount": 45,
    },
    {
        "id": "6", "name": "Компрессионная футболка", "brand": "RunTech",
        "categoryId": "tshirts", "price": 3490,
        "imageUrls": [
            "assets/images/products/1583743814966-8936f5b7be1a.jpg",
            "assets/images/products/1622519407650-3df9883f76a5.jpg",
            "assets/images/products/1503342217505-b0a15ec3261c.jpg",
        ],
        "description": "Компрессионная футболка с длинным рукавом. Поддерживает мышцы во время интенсивных тренировок. Анатомический крой по фигуре.",
        "sizes": ["S", "M", "L", "XL"],
        "colors": ["Чёрный", "Белый"],
        "rating": 4.5, "reviewCount": 38,
    },
    {
        "id": "7", "name": "Рюкзак Training Pack 25L", "brand": "UrbanFit",
        "categoryId": "accessories", "price": 6990,
        "imageUrls": [
            "assets/images/products/1553062407-98eeb64c6a62.jpg",
            "assets/images/products/1547949003-9792a18a2601.jpg",
            "assets/images/products/1622560480654-d96214fdc887.jpg",
        ],
        "description": "Вместительный спортивный рюкзак объёмом 25 литров. Отдельное отделение для обуви, карман для ноутбука, боковые карманы для бутылок.",
        "sizes": ["Один размер"],
        "colors": ["Чёрный", "Серый", "Хаки"],
        "isFeatured": True, "rating": 4.7, "reviewCount": 91,
    },
    {
        "id": "8", "name": "Зимняя куртка Thermo Pro", "brand": "ProGear",
        "categoryId": "jackets", "price": 14990,
        "imageUrls": [
            "assets/images/products/1544022613-e87ca75a784a.jpg",
            "assets/images/products/1520975954732-35dd22299614.jpg",
        ],
        "description": "Тёплая зимняя куртка с утеплителем PrimaLoft. Водонепроницаемое покрытие, проклеенные швы. Для экстремальных зимних тренировок и активного отдыха.",
        "sizes": ["S", "M", "L", "XL", "XXL"],
        "colors": ["Чёрный", "Тёмно-синий"],
        "rating": 4.9, "reviewCount": 156,
    },
    {
        "id": "9", "name": "Кроссовки Cloud Foam", "brand": "RunTech",
        "categoryId": "shoes", "price": 9990, "oldPrice": 12990,
        "imageUrls": [
            "assets/images/products/1595950653106-6c9ebd614d3a.jpg",
            "assets/images/products/1460353581641-37baddab0fa2.jpg",
            "assets/images/products/1551107696-a4b0c5a0d9a2.jpg",
        ],
        "description": "Лёгкие кроссовки с пеной Cloud Foam для максимальной амортизации. Дышащий верх и гибкая подошва. Идеальны для зала и повседневной носки.",
        "sizes": ["38", "39", "40", "41", "42", "43", "44"],
        "colors": ["Пастельный", "Белый/Серый", "Розовый"],
        "isNew": True, "isFeatured": True, "rating": 4.7, "reviewCount": 58,
    },
    {
        "id": "10", "name": "Кроссовки Street Pro", "brand": "ProGear",
        "categoryId": "shoes", "price": 11490,
        "imageUrls": [
            "assets/images/products/1539185441755-769473a23570.jpg",
            "assets/images/products/1595341888016-a392ef81b7de.jpg",
            "assets/images/products/1525966222134-fcfa99b8ae77.jpg",
        ],
        "description": "Городские кроссовки с усиленной пяткой и износостойкой подошвой. Универсальный дизайн для спорта и улицы.",
        "sizes": ["40", "41", "42", "43", "44", "45"],
        "colors": ["Хаки", "Бело-оранжевый", "Бордовый"],
        "isFeatured": True, "rating": 4.6, "reviewCount": 74,
    },
    {
        "id": "11", "name": "Лонгслив Active Long", "brand": "UrbanFit",
        "categoryId": "tshirts", "price": 3290,
        "imageUrls": [
            "assets/images/products/1578587018452-892bacefd3f2.jpg",
            "assets/images/products/1542060748-10c28b62716f.jpg",
        ],
        "description": "Лонгслив свободного кроя из плотного хлопка. Подходит для прохладной погоды и многослойных образов.",
        "sizes": ["XS", "S", "M", "L", "XL"],
        "colors": ["Оранжевый", "Чёрный", "Белый"],
        "isNew": True, "rating": 4.5, "reviewCount": 31,
    },
    {
        "id": "12", "name": "Футболка Statement", "brand": "SportStore",
        "categoryId": "tshirts", "price": 2490, "oldPrice": 3290,
        "imageUrls": [
            "assets/images/products/1527719327859-c6ce80353573.jpg",
            "assets/images/products/1581655353564-df123a1eb820.jpg",
            "assets/images/products/1576566588028-4147f3842f27.jpg",
        ],
        "description": "Хлопковая футболка с фирменным принтом. Прямой крой, плотный материал, насыщенный цвет после стирок.",
        "sizes": ["S", "M", "L", "XL", "XXL"],
        "colors": ["Белый", "Бежевый", "Чёрный"],
        "rating": 4.4, "reviewCount": 47,
    },
    {
        "id": "13", "name": "Шорты Denim Flex", "brand": "UrbanFit",
        "categoryId": "pants", "price": 3990,
        "imageUrls": [
            "assets/images/products/1591195853828-11db59a44f6b.jpg",
            "assets/images/products/1542272604-787c3835535d.jpg",
        ],
        "description": "Джинсовые шорты с эластаном для свободы движений. Универсальная посадка, потёртости ручной работы.",
        "sizes": ["XS", "S", "M", "L", "XL"],
        "colors": ["Светлый деним", "Тёмный деним"],
        "isNew": True, "rating": 4.3, "reviewCount": 22,
    },
    {
        "id": "14", "name": "Куртка Shearling Winter", "brand": "ProGear",
        "categoryId": "jackets", "price": 16990, "oldPrice": 21990,
        "imageUrls": [
            "assets/images/products/1559551409-dadc959f76b8.jpg",
            "assets/images/products/1520975954732-35dd22299614.jpg",
        ],
        "description": "Утеплённая куртка с меховой подкладкой шерпа. Защищает от ветра и мороза, сохраняя стиль. Премиальная фурнитура.",
        "sizes": ["S", "M", "L", "XL"],
        "colors": ["Коричневый", "Чёрный"],
        "isFeatured": True, "rating": 4.8, "reviewCount": 63,
    },
    {
        "id": "15", "name": "Бутылка Thermo 750 мл", "brand": "SportStore",
        "categoryId": "accessories", "price": 1490,
        "imageUrls": [
            "assets/images/products/1602143407151-7111542de6e8.jpg",
        ],
        "description": "Спортивная термобутылка из нержавеющей стали. Сохраняет холод 24 ч и тепло 12 ч. Матовое покрытие soft-touch.",
        "sizes": ["750 мл"],
        "colors": ["Зелёный", "Чёрный", "Белый"],
        "isNew": True, "rating": 4.9, "reviewCount": 112,
    },
    {
        "id": "16", "name": "Рюкзак Urban Daypack", "brand": "UrbanFit",
        "categoryId": "accessories", "price": 5490,
        "imageUrls": [
            "assets/images/products/1547949003-9792a18a2601.jpg",
            "assets/images/products/1553062407-98eeb64c6a62.jpg",
        ],
        "description": "Городской рюкзак на каждый день с отделением для ноутбука 15\". Водоотталкивающая ткань, эргономичные лямки.",
        "sizes": ["Один размер"],
        "colors": ["Серый", "Чёрный"],
        "rating": 4.6, "reviewCount": 39,
    },
]

BANNERS = [
    {
        "title": "НОВАЯ КОЛЛЕКЦИЯ\nВЕСНА 2025",
        "subtitle": "Спорт без границ",
        "imageUrl": "assets/images/products/1571019614242-c5c5dee9f50b.jpg",
        "action": "Смотреть",
    },
    {
        "title": "СКИДКИ\nДО 40%",
        "subtitle": "На беговую экипировку",
        "imageUrl": "assets/images/products/1544367567-0f2fcb009e0b.jpg",
        "action": "Купить",
    },
    {
        "title": "ЗИМНЯЯ\nЛИНЕЙКА",
        "subtitle": "Тепло и комфорт",
        "imageUrl": "assets/images/products/1517836357463-d25dfeac3438.jpg",
        "action": "Выбрать",
    },
]
