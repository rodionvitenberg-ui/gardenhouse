# backend/shop/management/commands/update_product_images.py
"""Find contextual images for shop products from Wikimedia Commons and attach them.

Searches Wikimedia Commons for a photo matching each product's botanical
context, verifies the image license is open (CC / Public Domain), downloads a
~1200px-wide version, and stores it on the Product.image ImageField.
"""

import json
import time
import urllib.parse
import urllib.request
from pathlib import Path

from django.core.files.base import ContentFile
from django.core.management.base import BaseCommand

from shop.models import Product

# ── Сопоставление товар → поисковый запрос на Wikimedia Commons ──
SEARCH_QUERIES = {
    "abrikos-korolevskij": "Prunus armeniaca Korolevskij apricot fruit",
    "chereshnya": "Prunus avium cherry tree fruit",
    "lavender-munstead": "Lavandula angustifolia 'Munstead'",
    "echinacea-white-swan": "Echinacea purpurea 'White Swan'",
    "hosta-francee": "Hosta 'Francee'",
    "peony-sarah-bernhardt": "Paeonia 'Sarah Bernhardt'",
    "russian-sage": "Perovskia atriplicifolia Russian sage",
    "daylily-stella-de-oro": "Hemerocallis 'Stella de Oro'",
    "apple-granny-smith": "Granny Smith apple",
    "cherry-stella": "Prunus avium 'Stella' cherry",
    "lilac-sensation": "Syringa vulgaris 'Sensation'",
    "hydrangea-limelight": "Hydrangea paniculata 'Limelight'",
    "plum-victoria": "Prunus domestica 'Victoria' plum",
    "sunflower-russian-giant": "Helianthus annuus Russian Giant sunflower",
    "wildflower-meadow-mix": "wildflower meadow mix native",
    "tomato-brandywine": "Brandywine tomato",
    "pumpkin-jack-o-lantern": "Jack-o'-lantern pumpkin",
    "sweet-pea-cupani": "Lathyrus odoratus 'Cupani' sweet pea",
}

API_URL = "https://commons.wikimedia.org/w/api.php"
USER_AGENT = "FathersGardenBot/1.0 (https://github.com/fathersgarden; contact: garden@example.com)"

ALLOWED_LICENSES = ("cc", "public domain", "cc0", "pdm", "gpl", "gfdl", "mit", "apache", "ods", "odbl")


def api_request(params: dict) -> dict:
    """Perform a MediaWiki API request with a polite User-Agent."""
    params.setdefault("format", "json")
    url = API_URL + "?" + urllib.parse.urlencode(params)
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.loads(resp.read().decode("utf-8"))


def find_image_candidates(query: str) -> list[str]:
    """Return file page titles matching the query on Wikimedia Commons."""
    data = api_request({
        "action": "query",
        "list": "search",
        "srsearch": f"{query} filetype:bitmap",
        "srnamespace": "6",
        "srlimit": "20",
    })
    return [item["title"] for item in data.get("query", {}).get("search", [])]


def license_allowed(extmetadata: dict) -> bool:
    """Return True if the page's short license is an open one."""
    short = (extmetadata.get("LicenseShortName", {}) or {}).get("value", "").lower()
    return any(tag in short for tag in ALLOWED_LICENSES)


def get_largest_image_url(titles: list[str]) -> str | None:
    """Return the imageinfo URL (~1200px wide) for the first allowed-title image."""
    if not titles:
        return None
    data = api_request({
        "action": "query",
        "prop": "imageinfo",
        "iiprop": "url|size|extmetadata",
        "iiurlwidth": "1200",
        "titles": "|".join(titles),
    })
    pages = data.get("query", {}).get("pages", {})
    for page in pages.values():
        # No imagerepository check: on commons.wikimedia.org itself files
        # report imagerepository "local" — that is the shared repository.
        extmetadata = page.get("extmetadata", {})
        if not license_allowed(extmetadata):
            continue
        imageinfo = page.get("imageinfo", [])
        if not imageinfo:
            continue
        thumb_url = imageinfo[0].get("thumburl")
        if thumb_url:
            return thumb_url
    return None


def search_and_resolve(query: str, fallback_query: str | None = None) -> str | None:
    """Search, then resolve to a download URL. Returns None on failure."""
    candidates = find_image_candidates(query)
    url = get_largest_image_url(candidates)
    if url:
        return url
    if fallback_query:
        time.sleep(1)
        candidates = find_image_candidates(fallback_query)
        return get_largest_image_url(candidates)
    return None


class Command(BaseCommand):
    help = "Find contextual images from Wikimedia Commons and attach them to products"

    def handle(self, *args, **options):
        products = Product.objects.all()
        updated = 0
        skipped = 0
        failed = []

        for product in products:
            self.stdout.write(f"Processing: {product.title} ({product.slug})")

            query = SEARCH_QUERIES.get(product.slug) or SEARCH_QUERIES.get(product.title)
            fallback = SEARCH_QUERIES.get(product.title) if query != SEARCH_QUERIES.get(product.title) else None

            if not query:
                self.stdout.write(self.style.WARNING(f"  No search query configured, skipping"))
                skipped += 1
                continue

            image_url = None
            for attempt_query in (query, fallback):
                if not attempt_query:
                    continue
                try:
                    image_url = search_and_resolve(attempt_query)
                    if image_url:
                        break
                except Exception as exc:  # noqa: BLE001
                    self.stdout.write(self.style.WARNING(f"  Search error: {exc}"))
                time.sleep(1)

            if not image_url:
                self.stdout.write(self.style.ERROR(f"  No suitable image found"))
                failed.append(product.slug)
                continue

            try:
                req = urllib.request.Request(image_url, headers={"User-Agent": USER_AGENT})
                with urllib.request.urlopen(req, timeout=60) as resp:
                    image_data = resp.read()

                ext = Path(urllib.parse.urlparse(image_url).path).suffix or ".jpg"
                filename = f"{product.slug}{ext}"
                product.image.save(filename, ContentFile(image_data), save=True)
                self.stdout.write(self.style.SUCCESS(f"  Attached: {product.image.name}"))
                updated += 1
            except Exception as exc:  # noqa: BLE001
                self.stdout.write(self.style.ERROR(f"  Download error: {exc}"))
                failed.append(product.slug)

            time.sleep(1)

        self.stdout.write(
            self.style.SUCCESS(
                f"Done: {updated} products updated, {skipped} skipped, {len(failed)} failed"
            )
        )
        if failed:
            self.stdout.write(self.style.WARNING(f"Failed slugs: {', '.join(failed)}"))