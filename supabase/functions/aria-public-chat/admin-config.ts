export function applyAdminLocks(
  ownerConfig: Record<string, unknown>,
  adminConfig: Record<string, unknown> | null | undefined,
  lockedFields: unknown,
): Record<string, unknown> {
  const result = { ...ownerConfig };
  if (!Array.isArray(lockedFields) || !adminConfig || typeof adminConfig !== "object") return result;
  for (const field of lockedFields) {
    if (typeof field === "string" && Object.prototype.hasOwnProperty.call(adminConfig, field)) {
      result[field] = adminConfig[field];
    }
  }
  return result;
}
