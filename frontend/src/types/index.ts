// --- Journal ---

export interface JournalArticle {
  id: number;
  title: string;
  slug: string;
  category: "gardenNotes" | "seasonalTips" | "guestStories";
  image: string;
  alt: string;
  content: string;
  description: string;
  date: string;
  is_published: boolean;
  created_at: string;
  updated_at: string;
}

// --- Shop (Categories & Products) ---

export interface Category {
  id: number;
  title: string;
  slug: string;
  description: string;
  image: string;
}

export interface Product {
  id: number;
  category: Category;
  title: string;
  slug: string;
  description: string;
  price: string;
  stock: number;
  status: 'AVAILABLE' | 'PREORDER' | 'OUT_OF_STOCK';
  image: string;
  is_active: boolean;
}

// --- Guests (Houses & Bookings) ---

export interface HouseImage {
  id: number;
  image: string;
}

export interface House {
  id: number;
  title: string;
  slug: string;
  description: string;
  max_guests: number;
  price_per_night: string;
  is_available: boolean;
  images: HouseImage[];
}

export type BookingStatus = 'PENDING' | 'CONFIRMED' | 'CANCELED';

export interface BookingRequest {
  id: number;
  house: number;
  guest_name: string;
  guest_phone: string;
  guest_email: string;
  check_in: string;
  check_out: string;
  comment: string;
  status: BookingStatus;
  created_at: string;
}

export interface BookingRequestPayload {
  house: number;
  guest_name: string;
  guest_phone: string;
  guest_email?: string;
  check_in: string;
  check_out: string;
  comment?: string;
}

// --- Gallery ---

export interface GalleryImage {
  id: number;
  image: string;
  caption: string;
  alt: string;
  category: string;
  sort_order: number;
}

// --- Orders ---

export type OrderStatus = 'NEW' | 'PROCESSING' | 'SHIPPED' | 'CANCELLED';

export interface OrderItem {
  id: number;
  product: Product;
  quantity: number;
  unit_price: string;
}

export interface Order {
  id: number;
  guest_name: string;
  guest_phone: string;
  guest_email: string;
  comment: string;
  status: OrderStatus;
  items: OrderItem[];
  created_at: string;
}

export interface OrderItemPayload {
  product_id: number;
  quantity: number;
}

export interface OrderCreatePayload {
  guest_name: string;
  guest_phone: string;
  guest_email?: string;
  comment?: string;
  items: OrderItemPayload[];
}
