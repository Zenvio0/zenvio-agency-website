export function trustedVisitorAddress(headers: Headers): string {
  const cloudflareAddress = headers.get("cf-connecting-ip")?.trim();
  return cloudflareAddress || "unknown";
}
