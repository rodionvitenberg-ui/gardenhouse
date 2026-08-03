import axios from 'axios';
import type {
  Category,
  Product,
  House,
  BookingRequest,
  BookingRequestPayload,
  GalleryImage,
  JournalArticle,
  Order,
  OrderCreatePayload,
} from '@/types';

// Browser: same-origin /gardenhouse/api (nginx → Django).
// Server (RSC / SSR): absolute loopback — see getServerApiUrl().
function resolveApiBase(): string {
  if (typeof window === "undefined") {
    const server = process.env.API_URL?.trim();
    if (server && /^https?:\/\//i.test(server)) return server.replace(/\/$/, "");
    return "http://127.0.0.1:8000/api";
  }
  return process.env.NEXT_PUBLIC_API_URL || "http://localhost:8000/api";
}

const api = axios.create({
  baseURL: resolveApiBase(),
  headers: {
    "Content-Type": "application/json",
  },
  // Avoid multi-minute hangs if Django is down
  timeout: 15000,
});

// Intercept requests to add Accept-Language header from the NEXT_LOCALE cookie
api.interceptors.request.use((config) => {
  if (typeof document !== 'undefined') {
    const match = document.cookie.match(/NEXT_LOCALE=(\w+)/);
    const locale = match?.[1] || 'en';
    config.headers['Accept-Language'] = locale;
  }
  return config;
});

/** DRF paginated response shape */
interface Paginated<T> {
  count: number;
  next: string | null;
  previous: string | null;
  results: T[];
}

/** Unwrap a DRF-paginated response, falling back to a plain array. */
function unwrapList<T>(data: T[] | Paginated<T>): T[] {
  if (Array.isArray(data)) return data;
  if (data && typeof data === 'object' && Array.isArray((data as Paginated<T>).results)) {
    return (data as Paginated<T>).results;
  }
  return [];
}

// --- Journal ---

export async function fetchJournalArticles(): Promise<JournalArticle[]> {
  const { data } = await api.get<JournalArticle[]>('journal/');
  return unwrapList(data);
}

export async function fetchJournalArticleBySlug(slug: string): Promise<JournalArticle | null> {
  try {
    const { data } = await api.get<JournalArticle>(`journal/${slug}/`);
    return data;
  } catch {
    return null;
  }
}

// --- Shop ---

export async function fetchCategories(): Promise<Category[]> {
  const { data } = await api.get<Category[]>('categories/');
  return unwrapList(data);
}

export async function fetchProducts(): Promise<Product[]> {
  const { data } = await api.get<Product[]>('products/');
  return unwrapList(data);
}

/** Fetch all products and find one by slug (client-side filter).
 *  Suitable for small garden-farm catalogues. */
export async function fetchProductBySlug(slug: string): Promise<Product | null> {
  const products = await fetchProducts();
  return products.find((p) => p.slug === slug) ?? null;
}

// --- Houses ---

export async function fetchHouses(): Promise<House[]> {
  const { data } = await api.get<House[]>('houses/');
  return unwrapList(data);
}

// --- Gallery ---

export async function fetchGalleryImages(): Promise<GalleryImage[]> {
  const { data } = await api.get<GalleryImage[]>('gallery/');
  return unwrapList(data);
}

// --- Bookings ---

export async function createBooking(payload: BookingRequestPayload): Promise<BookingRequest> {
  const { data } = await api.post<BookingRequest>('bookings/', payload);
  return data;
}

// --- Orders ---

export async function createOrder(payload: OrderCreatePayload): Promise<Order> {
  const { data } = await api.post<Order>('orders/', payload);
  return data;
}

export default api;
