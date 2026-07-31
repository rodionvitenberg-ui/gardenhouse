from datetime import date
from django.core.management.base import BaseCommand
from journal.models import JournalArticle


ARTICLES = [
    {
        "title": "Peonies are here",
        "slug": "peonies-are-here",
        "category": JournalArticle.Category.GARDEN_NOTES,
        "image": "",
        "alt": "Peony bush in full bloom",
        "description": "The first peonies opened this week after a long, wet spring — deep pink and fragrant.",
        "content": "<p>The first peonies opened this week after a long, wet spring — deep pink and fragrant.</p><p>This year's bloom is the best we've seen in five seasons. The 'Sarah Bernhardt' variety is putting on a show with dinner-plate-sized blossoms that smell like rosewater and honey.</p><p>We'll be cutting bouquets for the shop starting next week. Come by and take a bunch home — they'll fill your house with scent for a week or more.</p>",
        "date": date(2026, 6, 15),
    },
    {
        "title": "Late spring planting guide",
        "slug": "late-spring-planting-guide",
        "category": JournalArticle.Category.SEASONAL_TIPS,
        "image": "",
        "alt": "Hands planting seedlings",
        "description": "What to put in the ground now for a strong start before the summer heat settles in.",
        "content": "<p>What to put in the ground now for a strong start before the summer heat settles in.</p><p>By late spring the soil has warmed enough for tender plants. Here's what we're planting this week:</p><ul><li>Tomatoes — harden them off and get them in the ground after the last frost</li><li>Basil, dill, and coriander — direct sow in well-warmed soil</li><li>Zinnias and marigolds — they thrive in the heat and bring pollinators</li></ul><p>Water deeply in the morning, mulch generously, and your garden will coast through July.</p>",
        "date": date(2026, 5, 20),
    },
    {
        "title": "A week of quiet",
        "slug": "a-week-of-quiet",
        "category": JournalArticle.Category.GUEST_STORIES,
        "image": "",
        "alt": "Guest reading on a porch",
        "description": "Elena came from Bishkek with a stack of books and left with a jar of our apricot jam.",
        "content": "<p>Elena came from Bishkek with a stack of books and left with a jar of our apricot jam.</p><p>She spent most of her week on the porch under the walnut tree, reading and watching the light move across the garden. On her last day she helped us pick apricots for jam-making.</p><p>\"I didn't realize I needed to be somewhere that smelled like apricots and didn't ask for anything,\" she said as she left.</p><p>We think that's what the garden is for.</p>",
        "date": date(2026, 6, 10),
    },
    {
        "title": "Cherry harvest begins",
        "slug": "cherry-harvest-begins",
        "category": JournalArticle.Category.GARDEN_NOTES,
        "image": "",
        "alt": "Cherry tree with ripe fruit",
        "description": "The old cherry tree by the greenhouse is heavy with fruit. Come pick your own.",
        "content": "<p>The old cherry tree by the greenhouse is heavy with fruit. Come pick your own.</p><p>Our 'Stella' cherry tree is producing its best crop yet — deep, sweet, almost-black fruit that tastes like summer concentrated into a single bite.</p><p>We're offering pick-your-own on weekends through July. Bring a bucket and we'll send you home with enough for jam, pie, and eating straight from the bowl.</p>",
        "date": date(2026, 7, 5),
    },
    {
        "title": "Watering in the dry months",
        "slug": "watering-in-the-dry-months",
        "category": JournalArticle.Category.SEASONAL_TIPS,
        "image": "",
        "alt": "Irrigation channel in a garden",
        "description": "How we keep the garden thriving through the Issyk-Kul summer without wasting a drop.",
        "content": "<p>How we keep the garden thriving through the Issyk-Kul summer without wasting a drop.</p><p>Water is precious here. We use drip irrigation on all our beds — it puts water exactly where it's needed and loses almost nothing to evaporation.</p><p>A few tips: water before sunrise, not after sunset (wet leaves overnight invite fungus). Mulch everything with straw or wood chips. And group plants by water needs — your lavender doesn't want the same treatment as your tomatoes.</p>",
        "date": date(2026, 7, 12),
    },
    {
        "title": "An anniversary in the orchard",
        "slug": "an-anniversary-in-the-orchard",
        "category": JournalArticle.Category.GUEST_STORIES,
        "image": "",
        "alt": "Couple walking through orchard",
        "description": "Aidan and Meerim celebrated ten years with a weekend in the garden house and a bottle of local wine.",
        "content": "<p>Aidan and Meerim celebrated ten years with a weekend in the garden house and a bottle of local wine.</p><p>They arrived on a Friday evening, walked the orchard at sunset, and cooked dinner together in the outdoor kitchen. On Saturday they hiked to the lake and came back with wildflowers in their hair.</p><p>\"Ten years felt like a big number before we came here,\" Aidan said. \"Now it just feels like the beginning of something.\"</p><p>We love being the place where quiet celebrations happen.</p>",
        "date": date(2025, 8, 22),
    },
]


class Command(BaseCommand):
    help = "Seed the database with journal articles"

    def handle(self, *args, **options):
        created = 0
        for data in ARTICLES:
            _, was_created = JournalArticle.objects.get_or_create(
                slug=data["slug"],
                defaults=data,
            )
            if was_created:
                created += 1
                self.stdout.write(self.style.SUCCESS(f"  Created article '{data['title']}'"))

        self.stdout.write(self.style.SUCCESS(f"Articles: {created} created, {len(ARTICLES) - created} already exist"))