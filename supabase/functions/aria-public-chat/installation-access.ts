export function installationAccessError(
  installation: { enabled?: boolean; revoked_at?: string | null } | null,
  controls: { globally_enabled?: boolean } | null,
  ownerConfig: Record<string, unknown> | null,
): string | null {
  if (!installation || installation.enabled !== true || !!installation.revoked_at) {
    return "This assistant is currently unavailable";
  }
  if (controls?.globally_enabled === false) return "This assistant is currently unavailable";
  if (ownerConfig?.owner_enabled === false) return "This assistant has been disabled by the website owner";
  return null;
}
