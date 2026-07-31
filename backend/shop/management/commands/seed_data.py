from django.core.management.base import BaseCommand
from shop.models import Category, Product


CATEGORIES = [
    {
        "title": "Perennials",
        "slug": "perennials",
        "description": "Hardy perennials that return year after year — carefully selected for our climate.",
    },
    {
        "title": "Trees & Shrubs",
        "slug": "trees",
        "description": "Fruit trees, flowering shrubs, and ornamental woody plants for your garden.",
    },
    {
        "title": "Seeds",
        "slug": "seeds",
        "description": "Open-pollinated and heirloom seeds saved from our own harvest.",
    },
]

PRODUCTS = [
    # ───── Perennials ─────
    {
        "category_slug": "perennials",
        "title": "Lavender 'Munstead'",
        "slug": "lavender-munstead",
        "description": "Compact, fragrant English lavender with deep violet-blue spikes. Blooms June–August. Drought-tolerant once established.",
        "price": "8.50",
        "stock": 45,
        "status": Product.Availability.AVAILABLE,
    },
    {
        "category_slug": "perennials",
        "title": "Echinacea 'White Swan'",
        "slug": "echinacea-white-swan",
        "description": "Pure white coneflower with a copper-orange cone. A magnet for bees and butterflies. Blooms midsummer to early autumn.",
        "price": "9.00",
        "stock": 30,
        "status": Product.Availability.AVAILABLE,
    },
    {
        "category_slug": "perennials",
        "title": "Hosta 'Francee'",
        "slug": "hosta-francee",
        "description": "Large, heart-shaped leaves with dark green centres and crisp white margins. Thrives in shade. Lavender flowers in late summer.",
        "price": "11.00",
        "stock": 25,
        "status": Product.Availability.AVAILABLE,
    },
    {
        "category_slug": "perennials",
        "title": "Peony 'Sarah Bernhardt'",
        "slug": "peony-sarah-bernhardt",
        "description": "Classic double blush-pink peony with a sweet fragrance. A cut-flower favourite. Blooms late spring to early summer.",
        "price": "14.00",
        "stock": 20,
        "status": Product.Availability.PREORDER,
    },
    {
        "category_slug": "perennials",
        "title": "Russian Sage",
        "slug": "russian-sage",
        "description": "Airy clumps of grey-green foliage with tall spikes of lavender-blue flowers. Blooms from midsummer to frost. Extremely drought-tolerant.",
        "price": "7.50",
        "stock": 35,
        "status": Product.Availability.AVAILABLE,
    },
    {
        "category_slug": "perennials",
        "title": "Daylily 'Stella de Oro'",
        "slug": "daylily-stella-de-oro",
        "description": "Compact reblooming daylily with cheerful golden-yellow flowers. Blooms from late spring through autumn. Nearly indestructible.",
        "price": "6.50",
        "stock": 50,
        "status": Product.Availability.AVAILABLE,
    },
    # ───── Trees & Shrubs ─────
    {
        "category_slug": "trees",
        "title": "Apple 'Granny Smith'",
        "slug": "apple-granny-smith",
        "description": "Vigorous, heavy-cropping apple tree. Large, tangy green fruit perfect for pies and fresh eating. Harvest mid-autumn.",
        "price": "28.00",
        "stock": 12,
        "status": Product.Availability.AVAILABLE,
    },
    {
        "category_slug": "trees",
        "title": "Cherry 'Stella'",
        "slug": "cherry-stella",
        "description": "Self-fertile sweet cherry with large, dark-red, juicy fruit. Compact tree suitable for smaller gardens. Harvest late summer.",
        "price": "32.00",
        "stock": 8,
        "status": Product.Availability.OUT_OF_STOCK,
    },
    {
        "category_slug": "trees",
        "title": "Lilac 'Sensation'",
        "slug": "lilac-sensation",
        "description": "Striking bicolour lilac — deep purple flowers edged in white. Rich, sweet fragrance. Grows 3–4m. Blooms mid-spring.",
        "price": "22.00",
        "stock": 15,
        "status": Product.Availability.AVAILABLE,
    },
    {
        "category_slug": "trees",
        "title": "Hydrangea 'Limelight'",
        "slug": "hydrangea-limelight",
        "description": "Hardy panicle hydrangea with large, cone-shaped flower heads that open lime-green and turn pink in autumn. Blooms July–October.",
        "price": "18.00",
        "stock": 20,
        "status": Product.Availability.AVAILABLE,
    },
    {
        "category_slug": "trees",
        "title": "Plum 'Victoria'",
        "slug": "plum-victoria",
        "description": "Britain's favourite dessert plum. Heavy crops of golden-pink fruit with sweet, juicy flesh. Self-fertile. Harvest late summer.",
        "price": "30.00",
        "stock": 5,
        "status": Product.Availability.PREORDER,
    },
    # ───── Seeds ─────
    {
        "category_slug": "seeds",
        "title": "Sunflower 'Russian Giant'",
        "slug": "sunflower-russian-giant",
        "description": "Towering annual sunflower reaching 3–4m with enormous 30–40 cm flower heads. Excellent for seed saving and bird feed.",
        "price": "3.50",
        "stock": 100,
        "status": Product.Availability.AVAILABLE,
    },
    {
        "category_slug": "seeds",
        "title": "Wildflower Meadow Mix",
        "slug": "wildflower-meadow-mix",
        "description": "A curated blend of native annuals and perennials (cornflower, poppy, oxeye daisy, yarrow) for a low-maintenance meadow patch.",
        "price": "5.00",
        "stock": 60,
        "status": Product.Availability.AVAILABLE,
    },
    {
        "category_slug": "seeds",
        "title": "Tomato 'Brandywine'",
        "slug": "tomato-brandywine",
        "description": "Heirloom beefsteak tomato with rich, complex flavour. Potato-leaf foliage. Produces large pink-red fruits 80–90 days from transplant.",
        "price": "4.00",
        "stock": 75,
        "status": Product.Availability.AVAILABLE,
    },
    {
        "category_slug": "seeds",
        "title": "Pumpkin 'Jack O'Lantern'",
        "slug": "pumpkin-jack-o-lantern",
        "description": "Classic carving pumpkin with deep orange, ribbed fruits weighing 8–12 kg. Vigorous vines. Harvest 100–110 days from sowing.",
        "price": "3.00",
        "stock": 50,
        "status": Product.Availability.AVAILABLE,
    },
    {
        "category_slug": "seeds",
        "title": "Sweet Pea 'Cupani'",
        "slug": "sweet-pea-cupani",
        "description": "The original fragrant sweet pea. Deep maroon and violet bicolour flowers with an intense, heady perfume. Vigorous climber.",
        "price": "3.50",
        "stock": 80,
        "status": Product.Availability.AVAILABLE,
    },
]


class Command(BaseCommand):
    help = "Seed the database with initial categories and products"

    def handle(self, *args, **options):
        # ── Categories ──
        created_cats = 0
        for data in CATEGORIES:
            _, created = Category.objects.get_or_create(
                slug=data["slug"],
                defaults={
                    "title": data["title"],
                    "description": data["description"],
                },
            )
            if created:
                created_cats += 1
                self.stdout.write(self.style.SUCCESS(f"  Created category '{data['title']}'"))

        self.stdout.write(self.style.SUCCESS(f"Categories: {created_cats} created, {len(CATEGORIES) - created_cats} already exist"))

        # ── Products ──
        created_products = 0
        for data in PRODUCTS:
            try:
                category = Category.objects.get(slug=data.pop("category_slug"))
            except Category.DoesNotExist:
                self.stdout.write(self.style.WARNING(f"  Skipping '{data['title']}' — category not found"))
                continue

            _, created = Product.objects.get_or_create(
                slug=data["slug"],
                defaults={
                    "category": category,
                    "title": data["title"],
                    "description": data["description"],
                    "price": data["price"],
                    "stock": data["stock"],
                    "status": data["status"],
                },
            )
            if created:
                created_products += 1
                self.stdout.write(self.style.SUCCESS(f"  Created product '{data['title']}'"))

        self.stdout.write(self.style.SUCCESS(f"Products: {created_products} created, {len(PRODUCTS) - created_products} already exist"))