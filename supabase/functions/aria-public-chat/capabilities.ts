export function disabledCapability(message: string, config: Record<string, unknown>): string | null {
  const words = new Set(message.toLowerCase().match(/[a-z0-9]{3,}/g) ?? []);
  const has = (...terms: string[]) => terms.some(term => words.has(term));
  if (config.contact === false && has("contact", "phone", "email", "address", "location", "book", "booking", "appointment", "hours", "call")) {
    return "I'm not able to provide contact or booking details. Please use the website's contact page.";
  }
  if (config.recommendations === false && has("recommend", "recommendation", "suggest", "suggestion", "best", "suitable", "which", "choose")) {
    return "I'm not configured to make recommendations. I can still answer other approved business-information questions.";
  }
  if (config.services === false && has("service", "services", "product", "products", "price", "pricing", "cost", "offer", "offering")) {
    return "I'm not configured to answer service or product questions. Please explore the website for more information.";
  }
  return null;
}
