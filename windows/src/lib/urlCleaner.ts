const TRACKING_PARAMS = new Set([
  'utm_source',
  'utm_medium',
  'utm_campaign',
  'utm_term',
  'utm_content',
  'utm_id',
  'utm_name',
  'fbclid',
  'gclid',
  'gclsrc',
  'dclid',
  'msclkid',
  'mc_cid',
  'mc_eid',
  'igshid',
  'si',
  'spm',
  'ref_src',
  'ref_url',
  'yclid',
  '_hsenc',
  '_hsmi',
  'mkt_tok',
  'trk',
  'trkcampaign',
  'sc_cid',
  'share_id',
]);

export function cleanUrl(raw: string): { cleaned: string; removedCount: number; valid: boolean } {
  const trimmed = raw.trim();
  if (!trimmed) return { cleaned: '', removedCount: 0, valid: false };

  let normalized = trimmed;
  if (!/^https?:\/\//i.test(normalized)) {
    if (normalized.includes('.') && !normalized.includes(' ')) {
      normalized = `https://${normalized}`;
    } else {
      return { cleaned: trimmed, removedCount: 0, valid: false };
    }
  }

  try {
    const parsed = new URL(normalized);
    let removedCount = 0;
    for (const key of Array.from(parsed.searchParams.keys())) {
      const lower = key.toLowerCase();
      if (TRACKING_PARAMS.has(lower) || lower.startsWith('utm_')) {
        parsed.searchParams.delete(key);
        removedCount += 1;
      }
    }
    return { cleaned: parsed.toString(), removedCount, valid: true };
  } catch {
    return { cleaned: trimmed, removedCount: 0, valid: false };
  }
}

export function isLikelyUrl(text: string): boolean {
  const t = text.trim();
  return /^https?:\/\/\S+$/i.test(t);
}
