import { NextRequest, NextResponse } from "next/server";
import { routing } from "./i18n/routing";

/**
 * Thin locale proxy for production.
 *
 * next-intl's createMiddleware() + Next basePath=/gardenhouse hangs forever on
 * locale routes in production (confirmed on server: disable middleware.js → 200ms
 * responses; with createMiddleware → 15s timeout, 0 bytes). We only need:
 *   - ensure a locale prefix (ru|en)
 *   - set NEXT_LOCALE cookie for client axios Accept-Language
 * Messages / Link / useTranslations still come from next-intl without that middleware.
 */
export default function proxy(request: NextRequest) {
  const { pathname } = request.nextUrl;

  // pathname is WITHOUT basePath (Next strips it before proxy runs)
  const segment = pathname.split("/").filter(Boolean)[0];
  const locales = routing.locales as readonly string[];
  const defaultLocale = routing.defaultLocale;

  if (segment && locales.includes(segment)) {
    const res = NextResponse.next();
    res.cookies.set("NEXT_LOCALE", segment, {
      path: request.nextUrl.basePath || "/",
      sameSite: "lax",
    });
    return res;
  }

  // No locale prefix → redirect to default locale, keep rest of path + query
  const url = request.nextUrl.clone();
  const rest = pathname === "/" ? "" : pathname;
  url.pathname = `/${defaultLocale}${rest}`;
  return NextResponse.redirect(url);
}

export const config = {
  matcher: [
    // Skip API-ish, Next internals, and files with extensions
    "/((?!api|_next|_vercel|.*\\..*).*)",
  ],
};
