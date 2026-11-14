const TRACKING_PARAMS = new Set([
  'utm_source',
  'utm_medium',
  'utm_campaign',
  'utm_term',
  'utm_content',
  'utm_id',
  'fbclid',
  'gclid',
  'dclid',
  'gbraid',
  'wbraid',
  'msclkid',
  'mc_cid',
  'mc_eid',
  'yclid',
  'igshid',
  'si',
  'feature',
  'ref',
  'ref_src',
  'spm',
  '_hsenc',
  '_hsmi',
  'mkt_tok',
]);

export interface UrlCleanResult {
  cleaned: string;
  removedCount: number;
  removedKeys: string[];
  valid: boolean;
}

export function cleanTrackingUrl(rawInput: string): UrlCleanResult {
  const trimmed = rawInput.trim();
  if (!trimmed) {
    return { cleaned: '', removedCount: 0, removedKeys: [], valid: false };
  }

  let candidate = trimmed;
  if (!/^https?:\/\//i.test(candidate) && candidate.includes('.')) {
    candidate = `https://${candidate}`;
  }

  try {
    const parsed = new URL(candidate);
    const removedKeys: string[] = [];
    for (const key of Array.from(parsed.searchParams.keys())) {
      const lower = key.toLowerCase();
      if (TRACKING_PARAMS.has(lower) || lower.startsWith('utm_')) {
        removedKeys.push(key);
        parsed.searchParams.delete(key);
      }
    }
    return {
      cleaned: parsed.toString(),
      removedCount: removedKeys.length,
      removedKeys,
      valid: true,
    };
  } catch {
    return { cleaned: rawInput, removedCount: 0, removedKeys: [], valid: false };
  }
}
