# backend/scrapers/news_feed.py
# OpsFlood — NDMA + IMD + Bihar WRD News Feed Scraper
#
# Fetches alerts from:
#   IMD  RSS:     https://mausam.imd.gov.in/rss/
#   NDMA RSS:     https://ndma.gov.in/rss.xml
#   WRD Bulletins: https://www.fmiscwrdbihar.gov.in/bulletin/
#   CWC FFS:      https://beams.fmiscwrdbihar.gov.in
#
# Called every 30 min by Celery worker (or cron).
# Results cached in Redis for 25 min.
from __future__ import annotations

import hashlib
import re
import time
from datetime import datetime, timezone
from typing import Optional

import feedparser      # pip install feedparser
import requests
from bs4 import BeautifulSoup  # pip install beautifulsoup4

# ── Feed definitions ─────────────────────────────────────────────────────────
FEEDS = [
    {
        'source':   'IMD',
        'url':      'https://mausam.imd.gov.in/rss/warnings.xml',
        'fallback': 'https://mausam.imd.gov.in',
    },
    {
        'source':   'NDMA',
        'url':      'https://ndma.gov.in/media/disaster-alerts/feed/',
        'fallback': 'https://ndma.gov.in',
    },
    {
        'source':   'CWC',
        'url':      'https://cwc.gov.in/flood-forecast/rss',
        'fallback': 'https://beams.fmiscwrdbihar.gov.in',
    },
]

# Bihar keywords to filter relevant articles
BIHAR_KEYWORDS = [
    'bihar', 'ganga', 'kosi', 'gandak', 'bagmati', 'burhi gandak',
    'mahananda', 'ghaghra', 'kamla', 'punpun', 'supaul', 'sitamarhi',
    'darbhanga', 'muzaffarpur', 'patna', 'madhubani', 'saran', 'vaishali',
    'samastipur', 'khagaria', 'bhagalpur', 'purnia', 'kishanganj',
    'katihar', 'araria', 'gopalganj', 'siwan', 'buxar',
]

SEVERITY_PATTERNS = {
    'RED':    r'red\s*alert|extreme\s*rainfall|very\s*heavy|catastrophic',
    'ORANGE': r'orange\s*alert|heavy\s*to\s*very\s*heavy|severe\s*flood',
    'YELLOW': r'yellow\s*alert|heavy\s*rainfall|flood\s*warning|above\s*danger',
}


class NewsFeedScraper:
    def __init__(self, timeout: int = 10, max_age_hours: int = 72):
        self.timeout       = timeout
        self.max_age_hours = max_age_hours

    def fetch_all(self) -> list[dict]:
        """Fetch + merge all feeds, filtered to Bihar."""
        items: list[dict] = []
        for feed_cfg in FEEDS:
            try:
                items.extend(self._fetch_rss(feed_cfg))
            except Exception as exc:
                print(f'[NewsFeedScraper] {feed_cfg["source"]} failed: {exc}')
        # Deduplicate by title hash
        seen: set[str] = set()
        unique: list[dict] = []
        for item in items:
            h = hashlib.md5(item['title'].encode()).hexdigest()
            if h not in seen:
                seen.add(h)
                unique.append(item)
        # WRD Bihar bulletins (HTML scrape)
        try:
            unique.extend(self._fetch_wrd_bulletins())
        except Exception as exc:
            print(f'[NewsFeedScraper] WRD Bihar scrape failed: {exc}')
        # Sort newest first
        unique.sort(key=lambda x: x['published_at'], reverse=True)
        return unique

    # ── RSS feeds ─────────────────────────────────────────────────────────
    def _fetch_rss(self, cfg: dict) -> list[dict]:
        feed  = feedparser.parse(cfg['url'])
        items = []
        for entry in feed.entries:
            title = entry.get('title', '').strip()
            if not self._is_bihar_relevant(title):
                summary = entry.get('summary', '')
                if not self._is_bihar_relevant(summary):
                    continue
            published = self._parse_date(entry.get('published', ''))
            if not self._is_recent(published):
                continue
            items.append({
                'title':        title,
                'source':       cfg['source'],
                'summary':      self._clean(entry.get('summary', '')),
                'url':          entry.get('link'),
                'published_at': published.isoformat(),
                'severity':     self._detect_severity(title + ' ' + entry.get('summary', '')),
            })
        return items

    # ── Bihar WRD HTML scraper ─────────────────────────────────────────────
    def _fetch_wrd_bulletins(self) -> list[dict]:
        url  = 'https://www.fmiscwrdbihar.gov.in/bulletin/'
        resp = requests.get(url, timeout=self.timeout,
                            headers={'User-Agent': 'OpsFlood/2.0'})
        soup = BeautifulSoup(resp.text, 'html.parser')
        items: list[dict] = []
        for link in soup.select('a[href*=".pdf"], a[href*="bulletin"]')[:10]:
            title = link.get_text(strip=True)
            if len(title) < 10:
                continue
            href = link.get('href', '')
            if not href.startswith('http'):
                href = 'https://www.fmiscwrdbihar.gov.in' + href
            items.append({
                'title':        f'WRD Bihar Bulletin: {title}',
                'source':       'WRD Bihar',
                'summary':      'Official flood situation bulletin from Bihar Water Resources Dept.',
                'url':          href,
                'published_at': datetime.now(timezone.utc).isoformat(),
                'severity':     self._detect_severity(title),
            })
        return items

    # ── Helpers ───────────────────────────────────────────────────────────
    def _is_bihar_relevant(self, text: str) -> bool:
        t = text.lower()
        return any(kw in t for kw in BIHAR_KEYWORDS)

    def _detect_severity(self, text: str) -> Optional[str]:
        t = text.lower()
        for level, pattern in SEVERITY_PATTERNS.items():
            if re.search(pattern, t):
                return level
        return None

    def _parse_date(self, date_str: str) -> datetime:
        if not date_str:
            return datetime.now(timezone.utc)
        try:
            ts = feedparser._parse_date(date_str)  # type: ignore[attr-defined]
            if ts:
                return datetime(*ts[:6], tzinfo=timezone.utc)
        except Exception:
            pass
        return datetime.now(timezone.utc)

    def _is_recent(self, dt: datetime) -> bool:
        diff = datetime.now(timezone.utc) - dt.replace(tzinfo=timezone.utc)
        return diff.total_seconds() < self.max_age_hours * 3600

    @staticmethod
    def _clean(html: str) -> str:
        text = re.sub(r'<[^>]+>', '', html)
        return re.sub(r'\s+', ' ', text).strip()[:400]


# ── Flask/FastAPI route helper ─────────────────────────────────────────────
def get_news_json(state: str = 'bihar') -> list[dict]:
    """
    Main entry point for the API route GET /api/news?state=bihar
    Returns a list of NewsItem-compatible dicts.
    """
    scraper = NewsFeedScraper()
    return scraper.fetch_all()
